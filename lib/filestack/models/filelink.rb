require 'filestack/ruby/version'
require 'filestack/config'
require 'filestack/utils/utils'
require 'filestack/models/filestack_transform'
require 'filestack/mixins/filestack_common'

# This class represents a file stored on your Filestack
# storage.  Once initialized, you may perform transformations, conversions,
# get metadata, update, or delete it.
class FilestackFilelink
  include FilestackCommon
  include UploadUtils
  attr_reader :handle, :apikey, :security

  # Initialize FilestackFilelink
  #
  # @param [String]             file_handle   The FilestackFilelink handle
  # @param [String]             apikey        Your Filestack API Key (optional)
  # @param [FilestackSecurity]  security      Filestack security object, if
  #                                           security is enabled.
  def initialize(handle, apikey: nil, security: nil)
    @handle = handle
    @apikey = apikey
    @security = security
  end

  # Get content of filelink
  #
  # @return [Bytes]
  def get_content
    send_get_content(url)
  end

  # Download FilestackFilelink
  #
  # @param [String]              filepath     The local destination of the
  #                                           downloaded filelink
  # @return [Unirest::Response]
  def download(filepath)
    send_download(filepath)
  end

  # Delete filelink
  #
  # @return [Unirest::Response]
  def delete
    send_delete(handle, apikey, security)
  end

  # Ovewrite filelink by uploading local file
  #
  # @param [String]             filepath      filepath of file to upload
  #
  # @return [Unirest::Response]
  def overwrite(filepath)
    send_overwrite(filepath, handle, apikey, security)
  end

  # Turn the filelink into a transform object to perform
  # transform operations
  #
  # @return [Filestack::Transform]
  def transform
    Transform.new(handle: @handle, apikey: @apikey, security: @security)
  end

  # Return auto and user tags for the filelink
  #
  # @return [Hash]
  def tags
    send_tags('tags', @handle, @security)
  end

  # Return true (SFW) or false (NSFW)
  #
  # @return [Bool]
  def sfw 
    send_tags('sfw', @handle, @security)
  end

  # Get the URL of the FilestackFilelink
  #
  # @return [String]
  def url
    UploadUtils.get_url(
      FilestackConfig::CDN_URL, handle: handle, security: security
    )
  end
end
