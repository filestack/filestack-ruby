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
  # @param [Hash]                 options          User-supplied upload options
  #
  # return [Filestack::FilestackFilelink]
  def upload(filepath: nil, external_url: nil, options: {}, intelligent: false, timeout: 60, storage: 'S3')
    return 'You cannot upload a URL and file at the same time' if filepath && external_url

    response = if filepath
                 multipart_upload(@apikey, filepath, @security, options, timeout, storage, intelligent: intelligent)
               else
                 send_upload(@apikey,
                             external_url: external_url,
                             options: options,
                             security: @security)
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
