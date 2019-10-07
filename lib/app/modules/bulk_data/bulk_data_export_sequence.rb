# frozen_string_literal: true

module Inferno
  module Sequence
    class BulkDataExportSequence < SequenceBase
      group 'Bulk Data Export'

      title 'Bulk Data Export Tests'

      description 'Verify that system level export on the Bulk Data server follow the Bulk Data Access Implementation Guide'

      test_id_prefix 'System'

      requires :token

      attr_accessor :run_all_kick_off_tests

      def endpoint
        ''
      end

      def check_export_kick_off(search_params: nil)
        @search_params = search_params
        reply = export_kick_off(endpoint, search_params: search_params)

        # Servers unable to support _type SHOULD return an error and OperationOutcome resource
        # so clients can re-submit a request omitting the _type parameter.
        if search_params.present? && reply.code > 400
          response_body = JSON.parse(reply.body)
          message = ''
          response_body['issue'].each do |issue|
            message += issue['diagnostics'].presence || ''
          end

          skip message
        end

        @server_support_type_parameter = search_params.present?

        assert_response_accepted(reply)
        @content_location = reply.response[:headers]['content-location']

        assert @content_location.present?, 'Export response header did not include "Content-Location"'
      end

      def check_export_kick_off_fail_invalid_accept
        reply = export_kick_off(endpoint, headers: { accept: 'application/fhir+xml', prefer: 'respond-async' })
        assert_response_bad(reply)
      end

      def check_export_kick_off_fail_invalid_prefer
        reply = export_kick_off(endpoint, headers: { accept: 'application/fhir+json', prefer: 'return=representation' })
        assert_response_bad(reply)
      end

      def check_export_status(url = @content_location, timeout: 180)
        skip 'Server response did not have Content-Location in header' unless url.present?

        reply = export_status_check(url, timeout)

        # server response status code could be 202 (still processing), 200 (complete) or 4xx/5xx error code
        # export_status_check processes reponses with status 202 code
        # and returns server response when status code is not 202 or timed out

        skip "Server took more than #{timeout} seconds to process the request." if reply.code == 202

        assert reply.code == 200, "Bad response code: expected 200, 202, but found #{reply.code}."

        assert_response_content_type(reply, 'application/json')

        response_body = JSON.parse(reply.body)

        assert_status_reponse_required_field(response_body)

        @output = response_body['output']

        assert_output_has_type_url
      end

      def assert_output_has_type_url(output = @output,
                                     search_params = @search_params)
        skip 'Sever response did not have output data' unless output.present?

        search_type = search_params['_type'].split(',').map(&:strip) if search_params.present? && search_params.key?('_type')

        output.each do |file|
          ['type', 'url'].each do |key|
            assert file.key?(key), "Output file did not contain \"#{key}\" as required"
          end

          assert search_type.include?(file['type']), "Output file had type #{file['type']} not specified in export parameter #{search_params['_type']}" if search_type.present?
        end
      end

      def check_file_request(output = @output)
        skip 'Content-Location from server response was emtpy' unless output.present?

        headers = { accept: 'application/fhir+ndjson' }
        output.each do |file|
          url = file['url']
          type = file['type']
          reply = @client.get(url, @client.fhir_headers(headers))
          assert_response_content_type(reply, 'application/fhir+ndjson')

          check_ndjson(reply.body, type)
        end
      end

      def check_ndjson(ndjson, type)
        ndjson.each_line do |line|
          resource = FHIR.from_contents(line)
          assert resource.class.name.demodulize == type, "Resource in output file did not have type of \"#{type}\""
          errors = resource.validate
          assert errors.empty?, errors.to_s
        end
      end

      def check_delete_request(url)
        reply = @client.delete(url, {})
        skip 'Server did not accept client request to delete export file after export completed' if reply.code > 400
        assert_response_accepted(reply)
      end

      def check_cancel_request
        @content_location = nil
        check_export_kick_off
        check_delete_request(@content_location)
      end

      details %(

        The #{title} Sequence tests `#{title}` operations.  The operation steps will be checked for consistency against the
        [Bulk Data Access Implementation Guide](https://build.fhir.org/ig/HL7/bulk-data/)

      )

      @resources_found = false

      test 'Server rejects $export request without authorization' do
        metadata do
          id '01'
          link 'https://build.fhir.org/ig/HL7/bulk-data/export/index.html#bulk-data-kick-off-request'
          desc %(
          )
        end

        @client.set_no_auth
        skip 'Could not verify this functionality when bearer token is not set' if @instance.token.blank?

        reply = export_kick_off(endpoint)
        @client.set_bearer_token(@instance.token)
        assert_response_unauthorized reply
      end

      test 'Server shall return "202 Accepted" and "Content-location" for $export operation with parameters' do
        metadata do
          id '02'
          link 'https://build.fhir.org/ig/HL7/bulk-data/export/index.html#query-parameters'
          desc %(
          )
        end

        check_export_kick_off(search_params: { '_type' => endpoint })
      end

      test 'Server shall return "202 Accepted" and "Content-location" for $export operation' do
        metadata do
          id '03'
          link 'https://build.fhir.org/ig/HL7/bulk-data/export/index.html#bulk-data-kick-off-request'
          desc %(
          )
        end

        skip 'Skip testing $export without parameters' if @server_support_type_parameter && !run_all_kick_off_tests

        check_export_kick_off
      end

      test 'Server shall reject for $export operation with invalid Accept header' do
        metadata do
          id '04'
          link 'https://build.fhir.org/ig/HL7/bulk-data/export/index.html#headers'
          desc %(
          )
        end

        check_export_kick_off_fail_invalid_accept
      end

      test 'Server shall reject for $export operation with invalid Prefer header' do
        metadata do
          id '05'
          link 'https://build.fhir.org/ig/HL7/bulk-data/export/index.html#headers'
          desc %(
          )
        end

        check_export_kick_off_fail_invalid_prefer
      end

      test 'Server shall return "202 Accepted" or "200 OK"' do
        metadata do
          id '06'
          link 'https://build.fhir.org/ig/HL7/bulk-data/export/index.html#bulk-data-status-request'
          desc %(
          )
        end

        check_export_status
      end

      test 'Server shall return file in ndjson format' do
        metadata do
          id '07'
          link 'https://build.fhir.org/ig/HL7/bulk-data/export/index.html#file-request'
          desc %(
          )
        end

        check_file_request
      end

      test 'Server should return "202 Accepted" for delete export content' do
        metadata do
          id '08'
          link 'https://build.fhir.org/ig/HL7/bulk-data/export/index.html#bulk-data-delete-request'
          desc %(
          )
          optional
        end

        check_delete_request(@content_location)
      end

      test 'Server shall return "202 Accepted" for cancel export request' do
        metadata do
          id '09'
          link 'https://build.fhir.org/ig/HL7/bulk-data/export/index.html#bulk-data-delete-request'
          desc %(
          )
        end

        check_cancel_request
      end

      private

      def export_kick_off(endpoint = nil,
                          id: nil,
                          search_params: nil,
                          headers: { accept: 'application/fhir+json', prefer: 'respond-async' })
        url = ''
        url += "/#{endpoint}" if endpoint.present?
        url += "/#{id}" if endpoint.present? && id.present?
        url += '/$export'

        uri = Addressable::URI.parse(url)
        uri.query_values = search_params if search_params.present?
        full_url = uri.to_s

        @client.get(full_url, @client.fhir_headers(headers))
      end

      def export_status_check(url, timeout)
        wait_time = 1
        reply = nil
        headers = { accept: 'application/json' }
        start = Time.now

        loop do
          reply = @client.get(url, @client.fhir_headers(headers))

          wait_time = get_wait_time(wait_time, reply)
          seconds_used = Time.now - start + wait_time

          break if reply.code != 202 || seconds_used > timeout

          sleep wait_time
        end

        reply
      end

      def get_wait_time(wait_time, reply)
        retry_after = reply.response[:headers]['retry-after']
        retry_after_int = (retry_after.presence || 0).to_i

        if retry_after_int.positive?
          retry_after_int
        else
          wait_time * 2
        end
      end

      def delete_request(url)
        @client.delete(url)
      end

      def assert_status_reponse_required_field(response_body)
        ['transactionTime', 'request', 'requiresAccessToken', 'output', 'error'].each do |key|
          assert response_body.key?(key), "Complete Status response did not contain \"#{key}\" as required"
        end
      end
    end
  end
end
