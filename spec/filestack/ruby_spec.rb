require 'spec_helper'
require 'filestack/filelink'
require 'filestack/filestack_security'

RSpec.describe Filestack::Ruby do
  before(:each) do
    @test_handle = 'V059dRmSeWHT5WbiXssg'
    @test_apikey = 'YOUR_API_KEY'
    @test_secret = 'YOUR_SECRET'
    @test_filepath = __dir__ + '/../../test-files/calvinandhobbes.jpg'
  end

  #
  # Test for version number
  #
  it 'has a version number' do
    expect(Filestack::Ruby::VERSION).not_to be nil
  end

  #
  # Test calling Filelink.delete() successfully
  #
  it 'Filelink.delete called successfully' do
    mock_response = double('Typhoeus::Response')
    allow(mock_response).to receive(:code).and_return(200)

    security = FilestackSecurity.new(@test_secret)
    filelink = Filelink.new(@test_handle, @test_apikey, security)

    allow(filelink).to receive(:send_delete)
      .with(@test_handle, @test_apikey, security)
      .and_return(mock_response)

    response = filelink.delete
    expect(response.code).to eq(200)
  end

  #
  # Test calling Filelink.overwrite() successfully
  #
  it 'Filelink.overwrite called successfully' do
    mock_response = double('Typhoeus::Response')
    allow(mock_response).to receive(:code).and_return(200)

    security = FilestackSecurity.new(@test_secret)
    filelink = Filelink.new(@test_handle, @test_apikey, security)

    allow(filelink).to receive(:send_overwrite)
      .with(@test_filepath, @test_handle, @test_apikey, security)
      .and_return(mock_response)

    response = filelink.overwrite(@test_filepath)
    expect(response.code).to eq(200)
  end

  #
  # Test calling FilestackCommon.send_delete() successfully
  #
  it 'FilestackCommon.send_delete called successfully' do
    mock_response = double('Typhoeus::Response')
    allow(mock_response).to receive(:code).and_return(200)
    allow(Typhoeus).to receive(:delete).and_return(mock_response)

    security = FilestackSecurity.new(@test_secret)
    filestack_common = Object.new
    filestack_common.extend(FilestackCommon)
    response = filestack_common.send_delete(@test_handle,
                                            @test_apikey, security)

    expect(response.code).to eq(200)
  end

  #
  # Test calling FilestackCommon.send_delete() successfully
  #
  it 'FilestackCommon.send_overwrite called successfully' do
    mock_response = double('Typhoeus::Response')
    allow(mock_response).to receive(:code).and_return(200)

    mock_request = double('Typhoeus::Request')
    allow(mock_request).to receive(:run).and_return(mock_response)
    allow(Typhoeus::Request).to receive(:new).and_return(mock_request)

    security = FilestackSecurity.new(@test_secret)
    filestack_common = Object.new
    filestack_common.extend(FilestackCommon)
    response = filestack_common.send_overwrite(@test_filepath, @test_handle,
                                               @test_apikey, security)

    expect(response.code).to eq(200)
  end

  #
  # Test calling Filesecurity.generate() successfully
  #
  it 'Filesecurity.generate called successfully' do
    mock_hash = 'some-hash-value'
    mock_signature = 'some-signature-hash-value'

    allow(Base64).to receive(:urlsafe_encode64).and_return(mock_hash)
    allow(OpenSSL::HMAC).to receive(:hexdigest).and_return(mock_signature)

    options = {'expiry' => 3600}
    security = FilestackSecurity.new(@test_secret)
    security.generate(@test_secret, options)

    expect(security.policy).to eq(mock_hash)
    expect(security.signature).to eq(mock_signature)
  end

  #
  # Test calling Filesecurity.sign_url() successfully
  #
  it 'Filesecurity.sign_url called successfully' do
    security = FilestackSecurity.new(@test_secret)
    test_url = 'http://example-test.com'
    signed_url = security.sign_url(test_url)

    expect(signed_url).to include(test_url)
    expect(signed_url).to include('policy=')
    expect(signed_url).to include('signature=')
  end
end
