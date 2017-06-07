require 'filestack/ruby/version'
require 'filestack/mixins/filestack_common'

# This class represents a file stored on your Filestack
# storage.  Once initialized, you may perform transformations, conversions,
# get metadata, update, or delete it.
class Filelink
  include FilestackCommon
  attr_reader :file_handle, :apikey, :security

  # Initialize Filelink
  #
  # @param [String]             file_handle   The Filelink handle
  # @param [String]             apikey        Your Filestack API Key
  # @param [FilestackSecurity]  security      Filestack security object if
  #                                           security is enabled.
  #
  # @return [Typhoeus::Response]
  def initialize(file_handle, apikey, security = nil)
    @file_handle = file_handle
    @apikey = apikey
    @security = security
  end

  # Delete this filelink
  #
  # @return [Typhoeus::Response]
  def delete
    send_delete(file_handle, apikey, security)
  end

  # Ovewrite filelink by uploading local file
  #
  # @param [String]             filepath      filepath of file to upload
  #
  # @return [Typhoeus::Response]
  def overwrite(filepath)
    send_overwrite(filepath, file_handle, apikey, security)
  end
end
