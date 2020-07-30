# frozen_string_literal: true

require_relative '../generator_base'
require_relative '../sequence_metadata'
require_relative '../search_parameter_metadata'
require_relative './read_test'
require_relative './profile_validation_test'
require_relative './search_test'

module Inferno
  module Generator
    class GenericGenerator < Generator::Base
      include ReadTest
      include ProfileValidationTest
      include SearchTest

      def resource_profiles
        resources_by_type['StructureDefinition'].reject { |definition| definition['type'] == 'Extension' }
      end

      def sequence_metadata
        @sequence_metadata ||= resource_profiles.map { |profile| SequenceMetadata.new(profile, search_parameter_metadata, capability_statement) }
      end

      def search_parameter_metadata
        @search_parameter_metadata ||= resources_by_type['SearchParameter'].map { |parameter_json| SearchParameterMetadata.new(parameter_json) }
      end

      def generate
        generate_sequences
        copy_static_files
        generate_module
      end

      def generate_sequences
        sequence_metadata.each do |metadata|
          create_read_test(metadata)
          create_profile_validation_test(metadata)
          create_search_tests(metadata)
          generate_sequence(metadata)
        end
      end

      def generate_sequence(metadata)
        puts "Generating #{metadata.title}\n"
        file_name = File.join(sequence_out_path, metadata.file_name + '.rb')
        template = ERB.new(File.read(File.join(__dir__, 'templates/sequence.rb.erb')))
        output =   template.result_with_hash(metadata: metadata)
        FileUtils.mkdir_p(sequence_out_path + '/') unless File.directory?(sequence_out_path + '/')
        File.write(file_name, output)

        generate_sequence_definitions(metadata)
      end

      def generate_sequence_definitions(metadata)
        file_name = sequence_out_path + '/profile_definitions/' + metadata.file_name + '_definitions.rb'
        template = ERB.new(File.read(File.join(__dir__, 'templates/sequence_definition.rb.erb')))
        output = template.result_with_hash(sequence_definition_hash(metadata))
        FileUtils.mkdir_p(sequence_out_path + '/profile_definitions/') unless File.directory?(sequence_out_path + '/profile_definitions/')
        File.write(file_name, output)
      end

      def sequence_definition_hash(metadata)
        search_parameters = metadata.search_parameter_metadata&.map do |param_metadata|
          {
            url: param_metadata.url,
            code: param_metadata.code,
            expression: param_metadata.expression,
            multipleOr: param_metadata.multiple_or,
            multipleOrExpectation: param_metadata.multiple_or_expectation,
            multipleAnd: param_metadata.multiple_and,
            multipleAndExpectation: param_metadata.multiple_and_expectation,
            modifiers: param_metadata.modifiers,
            comparators: param_metadata.comparators
          }
        end
        search_parameters ||= []
        {
          class_name: metadata.class_name + 'Definition',
          search_parameters: structure_to_string(search_parameters)
        }
      end

      def structure_to_string(struct)
        if struct.is_a? Hash
          %({
            #{struct.map { |k, v| "#{k}: #{structure_to_string(v)}" }.join(",\n")}
          })
        elsif struct.is_a? Array
          if struct.empty?
            '[]'
          else
            %([
              #{struct.map { |el| structure_to_string(el) }.join(",\n")}
            ])
          end
        elsif struct.is_a? String
          "'#{struct}'"
        elsif [true, false].include? struct
          struct.to_s
        else
          "''"
        end
      end

      def module_file_path
        "#{module_yml_out_path}/#{@path}_module.yml"
      end

      def generate_module
        file_name = module_file_path

        module_info = {
          title: @path,
          sequences: sequence_metadata,
          description: ''
        }
        template = ERB.new(File.read(File.join(__dir__, 'templates/module.yml.erb')))
        output = template.result_with_hash(module_info)

        File.write(file_name, output)
      end

      def copy_static_files
        Dir.glob(File.join(__dir__, 'static', '*')).each do |static_file|
          FileUtils.cp(static_file, sequence_out_path)
        end
      end
    end
  end
end
