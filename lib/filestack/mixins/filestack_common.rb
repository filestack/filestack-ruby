require 'filestack/config'
require 'filestack/utils/utils'
require 'filestack/utils/multipart_upload_utils'
require 'mimemagic'
require 'typhoeus'

# Module is mixin for common functionalities that all Filestack
# objects can call.
module FilestackCommon
  include UploadUtils
  # Get the contents of a Filestack handle
  #
  # @param [String]             file_handle   The Filelink handle
  # @param [FilestackSecurity]  security      Optional Filestack security object
  #                                           if security is enabled
  #
  # @return [Bytes]
  def send_get_content(url, parameters: nil)
    UploadUtils.make_call(url, 'get', parameters: parameters)
  end

  # Get the content of a filehandle
  #
  # @param [String]             filepath      Local path of file to be written
  #
  # @return [Int]                             Size of file written
  def send_download(filepath)
    content = send_get_content(url)
    puts filepath
    File.write(filepath, content.body)
  end

  # Send the delete api request to delete a filelink
  #
  # @param [String]             url           The url of the Filehandle
  #                                           to be deleted (includes security)
  #
  # @return [unirest::Response]
  def send_delete(handle, apikey, security)
    return 'Delete requires security' if security.nil?
    signature = security.signature
    policy = security.policy
    base = "#{FilestackConfig::API_URL}/file"
    UploadUtils.make_call(
      "#{base}/#{handle}?key=#{apikey}&signature=#{signature}&policy=#{policy}",
      'delete'
    )
  end

  # Send the overwrite api request to update a filelink
  #
  # @param [String]             filepath      Filepath of file to upload
  # @param [String]             handle        The Filelink handle
  # @param [String]             apikey        Filestack API Key
  # @param [FilestackSecurity]  security      Filestack security object
  #
  # @return [Typhoeus::Response]
  def send_overwrite(filepath, handle, apikey, security)
    return 'Overwrite requires security' if security.nil?

    file = File.open(filepath, 'r')
    mimetype = MimeMagic.by_magic(file)
    content = file.read

    signature = security.signature
    policy = security.policy

    headers = { 'Content-Type' => mimetype }
    base = "#{FilestackConfig::API_URL}/file"

    UploadUtils.make_call(
      "#{base}/#{handle}?key=#{apikey}&signature=#{signature}&policy=#{policy}",
      'put',
      headers: headers,
      parameters: content
    )
  end
end
