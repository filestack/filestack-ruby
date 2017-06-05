require "spec_helper"
require "filestack/filelink"
require "filestack/filestack_security"

RSpec.describe Filestack::Ruby do

  before(:each) do
    @test_handle = 'some_file_handle'
    @test_apikey = 'YOUR_API_KEY'
    @test_secret = 'YOUR_SECURITY_SECRET'
    @test_filepath = __dir__ + '/../../test-files/calvinandhobbes.jpg'
  end

  it "has a version number" do
    expect(Filestack::Ruby::VERSION).not_to be nil
  end

  it "Filelink.overwrite called successfully" do

    security = FilestackSecurity.new(@test_secret)
    filelink = Filelink.new(@test_handle, @test_apikey, security)
    response = filelink.overwrite(@test_filepath)

    expect(response.code).to eq(200)
  end

  it "Filelink.overwrite called not found" do

    security = FilestackSecurity.new(@test_secret)
    filelink = Filelink.new(@test_handle, @test_apikey, security)
    response = filelink.overwrite(@test_filepath)

    expect(response.code).to eq(404)
  end

  it "Filelink.delete called successfully" do

    security = FilestackSecurity.new(@test_secret)
    filelink = Filelink.new(@test_handle, @test_apikey, security)
    response = filelink.delete()

    expect(response.code).to eq(200)
  end

  it "Filelink.delete called not found" do

    security = FilestackSecurity.new(@test_secret)
    filelink = Filelink.new(@test_handle, @test_apikey, security)
    response = filelink.delete()

    expect(response.code).to eq(404)
  end
end
