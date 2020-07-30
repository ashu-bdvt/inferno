# frozen_string_literal: true

module Inferno
  module Generator
    class SearchParameterMetadata
      attr_reader :search_parameter_json
      attr_writer :url,
                  :code,
                  :type,
                  :expression,
                  :multiple_or,
                  :multiple_or_expectation,
                  :multiple_and,
                  :multiple_and_expectation,
                  :modifiers,
                  :comparators

      EXPECTATION_URL = 'http://hl7.org/fhir/StructureDefinition/capabilitystatement-expectation'
      def initialize(search_parameter_json)
        @search_parameter_json = search_parameter_json
      end

      def url
        @url ||= @search_parameter_json['url']
      end

      def code
        @code ||= @search_parameter_json['code']
      end

      def type
        @type ||= @search_parameter_json['type']
      end

      def expression
        @expression ||= @search_parameter_json['expression']
      end

      # whether multiple or is allowed
      def multiple_or
        @multiple_or ||= @search_parameter_json['multipleOr']
      end

      # expectation if multiple or is allowed - unsure if this is generic or just us core specific
      def multiple_or_expectation
        @multiple_or_expectation ||= @search_parameter_json['_multipleOr']['extension'].find { |ext| ext['url'] == EXPECTATION_URL }['valueCode']
      end

      # whether multiple and is allowed
      def multiple_and
        @multiple_and ||= @search_parameter_json['multipleAnd']
      end

      # expectation if multiple and is allowed - unsure if this is generic or just us core specific
      def multiple_and_expectation
        @multiple_and_expectation ||= @search_parameter_json['_multipleAnd']['extension'].find { |ext| ext['url'] == EXPECTATION_URL }['valueCode']
      end

      def comparators
        return [] if @search_parameter_json['comparator'].nil?

        @comparators ||= @search_parameter_json['comparator'].each_with_index.map do |comparator, index|
          expectation_extension = @search_parameter_json['_comparator'] # unsure if this is us core specific
          expectation = expectation_extension[index]['extension'].find { |ext| ext['url'] == EXPECTATION_URL }['valueCode'] unless expectation_extension.nil?
          { comparator: comparator, expectation: expectation }
        end
      end

      def modifiers
        return [] if @search_parameter_json['modifier'].nil?

        @modifiers ||= @search_parameter_json['modifier'].each_with_index.map do |modifier, index|
          expectation_extension = @search_parameter_json['_modifier'] # unsure if this is us core specific
          expectation = expectation_extension[index]['extension'].find { |ext| ext['url'] == EXPECTATION_URL }['valueCode'] unless expectation_extension.nil?
          { modifier: modifier, expectation: expectation }
        end
      end
    end
  end
end