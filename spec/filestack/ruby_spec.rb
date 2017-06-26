require 'simplecov'
SimpleCov.start 

require 'spec_helper'
require './lib/filestack'
require 'filestack/config'
require 'filestack/mixins/filestack_common'
require 'filestack/utils/multipart_upload_utils'
require 'filestack/utils/utils'

include MultipartUploadUtils
include UploadUtils
include FilestackCommon

class Response
  def body
    'thisissomecontent'
  end

  def code
    200
  end
end

class GeneralResponse
  attr_reader :body

  def initialize(body_content)
    @body = body_content
  end
end


RSpec.describe Filestack::Ruby do
  before(:each) do
    @test_handle = 'V059dRmSeWHT5WbiXssg'
    @test_apikey = 'YOUR_API_KEY'
    @test_secret = 'YOUR_SECRET'
    @test_filepath = __dir__ + '/../../test-files/calvinandhobbes.jpg'
    @test_download =  __dir__ + '/../../test-files/test'
    @test_filename = 'calvinandhobbes.jpg'
    @test_filesize = 10000
    @test_mimetype = 'image/jpeg'
    @start_response = {
      uri: 'uri',
      region: 'region',
      upload_id: 'upload_id',
      location_url: 'location_url'
    }
    @job = {
      seek: 0,
      filepath: @test_filepath,
      filename: @test_filename,
      apikey: @test_apikey,
      part: 1,
      uri: @start_response[:uri],
      region: @start_response[:region],
      upload_id: @start_response[:upload_id],
      location_url: @start_response[:location_url]
    }
    @response = Response.new
    @test_client = Client.new(@test_apikey)
    @test_filelink = Filelink.new(@test_handle)
    @test_security = FilestackSecurity.new(@test_secret)
    @test_secure_filelink = Filelink.new(@test_apikey, security: @test_security)
    @test_transform = Transform.new(apikey: @test_apikey, handle: @test_handle)
  end

  it 'has a version number' do
    expect(Filestack::Ruby::VERSION).not_to be nil
  end

  it 'Filesecurity.generate called successfully' do
    mock_hash = 'some-hash-value'
    mock_signature = 'some-signature-hash-value'

    allow(Base64).to receive(:urlsafe_encode64).and_return(mock_hash)
    allow(OpenSSL::HMAC).to receive(:hexdigest).and_return(mock_signature)

    options = { 'expiry' => 3600 }
    security = FilestackSecurity.new(@test_secret)
    security.generate(@test_secret, options)

    expect(security.policy).to eq(mock_hash)
    expect(security.signature).to eq(mock_signature)
  end

  it 'Filesecurity.sign_url called successfully' do
    security = FilestackSecurity.new(@test_secret)
    test_url = 'http://example-test.com'
    signed_url = security.sign_url(test_url)

    expect(signed_url).to include(test_url)
    expect(signed_url).to include('policy=')
    expect(signed_url).to include('signature=')
  end

  ######################
  ## MULTIPART TESTING #
  ######################

  it 'returns the right file info' do
    allow(File).to receive(:basename).and_return(@test_filename)
    allow(File).to receive(:size).and_return(@test_filesize)

    filename, filesize, mimetype =
      MultipartUploadUtils.get_file_info(@test_filepath)

    expect(filename).to eq(@test_filename)
    expect(filesize).to eq(@test_filesize)
    expect(mimetype).to eq(@test_mimetype)
  end

  it 'returns the correct multipart_start response' do
    allow(Unirest).to receive(:post)
      .and_return(@response)

    response = MultipartUploadUtils.multipart_start(
      @test_apikey, @test_filename, @test_filesize, 
      @start_response, nil, nil
    )
    expect(response).to eq('thisissomecontent')
  end

  it 'returns the correct create_upload_jobs array' do
    jobs = create_upload_jobs(
      @test_apikey, @test_filename, @test_filepath,
      @test_filesize, @start_response, nil
    )
    expect(jobs[0][:filepath]).to eq(@test_filepath)
  end

  it 'returns correct upload_chunk response' do
    class FilestackResponse
      def body
        {
          url: 'someurl',
          headers: 'seomheaders'
        }
      end
    end
    allow(Unirest).to receive(:post).and_return(FilestackResponse.new)
    allow(Unirest).to receive(:put)
      .and_return(@response)

    response = MultipartUploadUtils.upload_chunk(
      @job, @test_apikey, @start_response['location_url'], @test_filepath, nil
    )
    expect(response.body).to eq('thisissomecontent')
  end

  it 'returns the correct parallel results' do
    class HeadersResponse
      def headers
        { etag: 'someetag' }
      end
    end

    jobs = []
    2.times do
      jobs.push(@job)
    end
    part = @job[:part]
    result_string = "#{part}:someetag"

    allow(MultipartUploadUtils).to receive(:upload_chunk)
      .and_return(HeadersResponse.new)
    target_results = []
    2.times do
      target_results.push(result_string)
    end

    results = MultipartUploadUtils.run_uploads(
      jobs, @test_apikey, @test_filepath, nil
    )
    2.times do |i|
      expect(results[i]).to eq(result_string)
    end
  end

  it 'returns the correct multipart_complete response' do
    allow(Unirest).to receive(:post).and_return(@response)
    response = MultipartUploadUtils.multipart_complete(
      @test_apikey, @test_filename, @test_filesize, @test_mimetype,
      @start_response, %w[somepartsandetags somepartsandetags], nil
    )
    expect(response.body).to eq(@response.body)
  end

  it 'Multipart upload returns the correct response' do
    allow(MultipartUploadUtils).to receive(:multipart_upload)
      .and_return(@response)
    response = MultipartUploadUtils.multipart_upload(
      @test_apikey, @test_filepath
    )
    expect(response.body).to eq(@response.body)
  end

  #########################
  ## COMMON MIXIN TESTING #
  #########################

  it 'gets contents of a filelink' do
    allow(UploadUtils).to receive(:make_call)
      .and_return(@response.body)
    content = @test_filelink.get_content
    expect(content).to eq(@response.body)
  end

  it 'downloads a filelink' do
    allow(UploadUtils).to receive(:make_call)
      .and_return(@response)

    response = @test_filelink.download(@test_download)
    expect(response).to eq(@response.body.length)
    File.delete(@test_download)
  end

  it 'deletes a filelink' do
    allow(UploadUtils).to receive(:make_call)
      .and_return(@response)

    delete = @test_secure_filelink.delete()
    expect(delete.body).to eq(@response.body)
  end

  it 'does not delete an unsecure filelink' do
    bad = @test_filelink.delete
    expect(bad).to eq('Delete requires security')
  end

  it 'overwrites a filelink' do
    allow(UploadUtils).to receive(:make_call)
      .and_return(@response)
    overwrite = @test_secure_filelink.overwrite(@test_filepath)
    expect(overwrite.body).to eq(@response.body)
  end

  it 'does not ovewrite an unsecure filelink' do
    bad = @test_filelink.overwrite(@test_filepath)
    expect(bad).to eq('Overwrite requires security')
  end

  ###################
  ## TRANFORM TESTS #
  ###################

  it 'calls the correct transform methods' do
    TransformConfig::TRANSFORMATIONS.each do |transformation|
      @test_transform.public_send(transformation, width: 100, height: 100)
    end
  end

  it 'does not call the wrong transform method' do
    expect {
      lambda @test_transform.wrong_transformation(width: 100, height: 100)
    }.to raise_error(NoMethodError)
  end

  it 'creates AV class' do
    class AVstatus
      def body
        { 'status' => 'completed' }
      end
    end

    class AVresponse
      def body
        { 'status' => 'completed',
          'data' => {
            'url' => 'https://cdn.filestackcontent.com/somehandle'
          } }
      end
    end
    allow(Unirest).to receive(:post).and_return(@response)
    allow(Unirest).to receive(:get).and_return(AVresponse.new)
    av = @test_transform.av_convert(width: 100, height: 100)
    expect(av.status).to eq('completed')
    expect(av.to_filelink.handle).to eq('somehandle')
  end

  it 'stores a transformation url' do
    transform_content = { 'url' => 'https://cdn.filestack.com/somehandle' }
    allow(Unirest).to receive(:get)
      .and_return(GeneralResponse.new(transform_content))
    expect(@test_transform.store.handle).to eq('somehandle')
  end

  it 'returns a debug object' do
    debug_content = { 'metadata' => { 'width' => 500 } }
    allow(Unirest).to receive(:get)
      .and_return(GeneralResponse.new(debug_content))
    debug = @test_transform.resize(width: 100).debug
    expect(debug['metadata']['width']).to eq(500)
  end

  ###############
  ## TAGS TESTS #
  ###############

  it 'returns tags' do
    tag_content = { 'tags' => { 'tag' => 'sometag' } }
    allow(Unirest).to receive(:get).and_return(GeneralResponse.new(tag_content))
    tags = @test_secure_filelink.tags
    expect(tags['tag']).to eq('sometag')
  end

  it 'returns sfw' do
    sfw_content = { 'sfw' => { 'sfw' => 'true' } }
    allow(Unirest).to receive(:get).and_return(GeneralResponse.new(sfw_content))
    sfw = @test_secure_filelink.sfw
    expect(sfw['sfw']).to eq('true')
  end
end
