# frozen_string_literal: true

require_relative '../../../../test/test_helper'

describe Inferno::Sequence::USCore310LocationSequence do
  before do
    @sequence_class = Inferno::Sequence::USCore310LocationSequence
    @base_url = 'http://www.example.com/fhir'
    @client = FHIR::Client.new(@base_url)
    @token = 'ABC'
    @instance = Inferno::Models::TestingInstance.create(token: @token)
    @patient_id = '123'
    @instance.patient_id = @patient_id
    @auth_header = { 'Authorization' => "Bearer #{@token}" }
  end

  describe 'unauthorized search test' do
    before do
      @test = @sequence_class[:unauthorized_search]
      @sequence = @sequence_class.new(@instance, @client)

      @location_ary = load_json_fixture(:us_core_location_location_ary)
        .map { |resource| FHIR.from_contents(resource.to_json) }
      @sequence.instance_variable_set(:'@location_ary', @location_ary)

      @query = {
        'name': @sequence.get_value_for_search_param(@sequence.resolve_element_from_path(@location_ary, 'name'))
      }
    end

    it 'fails when the token refresh response has a success status' do
      stub_request(:get, "#{@base_url}/Location")
        .with(query: @query)
        .to_return(status: 200)

      exception = assert_raises(Inferno::AssertionException) { @sequence.run_test(@test) }

      assert_equal 'Bad response code: expected 401, but found 200', exception.message
    end

    it 'succeeds when the token refresh response has an error status' do
      stub_request(:get, "#{@base_url}/Location")
        .with(query: @query)
        .to_return(status: 401)

      @sequence.run_test(@test)
    end

    it 'is omitted when no token is set' do
      @instance.token = ''

      exception = assert_raises(Inferno::OmitException) { @sequence.run_test(@test) }

      assert_equal 'Do not test if no bearer token set', exception.message
    end
  end
end
