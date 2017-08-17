require 'filestack/config'
require 'filestack/utils/multipart_upload_utils'
require 'filestack/models/filestack_transform'
require 'filestack/utils/utils'
require 'json'

# The Filestack FilestackClient class acts as a hub for all
# Filestack actions that do not require a file handle, including
# uploading files (both local and external), initiating an external
# transformation, and other tasks
class FilestackClient
  include MultipartUploadUtils
  include UploadUtils
  attr_reader :apikey, :security

  # Initialize FilestackClient
  #
  # @param [String]               apikey        Your Filestack API key
  # @param [FilestackSecurity]    security      A Filestack security object,
  #                                             if security is enabled
  def initialize(apikey, security: nil)
    @apikey = apikey
    @security = security
  end

  # Upload a local file or external url
  # @param [String]               filepath         The path of a local file
  # @param [String]               external_url     An external URL
  # @param [Bool]                 multipart        Switch for miltipart
  #                                                    (Default: true)
  # @param [Hash]                 options          User-supplied upload options
  #
  # return [Filestack::FilestackFilelink]
  def upload(filepath: nil, external_url: nil, multipart: true, options: nil, storage: 's3', intelligent: false, timeout: 60)
    if filepath && external_url
      return 'You cannot upload a URL and file at the same time'
    end
    response = if filepath && multipart
                 multipart_upload(@apikey, filepath, @security, options, timeout, intelligent: intelligent)
               else
                 send_upload(
                   @apikey,
                   filepath: filepath,
                   external_url: external_url,
                   options: options,
                   security: @security,
                   storage: storage
                 )
               end
    FilestackFilelink.new(response['handle'], security: @security, apikey: @apikey)
  end
  # Transform an external URL 
  #
  # @param [string]    external_url   A valid URL 
  #
  # @return [Filestack::Transform]
  def transform_external(external_url)
    Transform.new(external_url: external_url, security: @security, apikey: @apikey)
  end  

  def zip(destination, files)    
    encoded_files = JSON.generate(files).gsub('"', '')
    zip_url = "#{FilestackConfig::CDN_URL}/#{@apikey}/zip/#{encoded_files}"
    escaped_zip_url = zip_url.gsub("[","%5B").gsub("]","%5D")
    response = UploadUtils.make_call(escaped_zip_url, 'get')    
    File.write(destination, response.body)
  end
end
