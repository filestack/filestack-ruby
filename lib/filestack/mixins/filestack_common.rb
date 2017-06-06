require 'filestack/config'
require 'typhoeus'

# Module is mixin for common functionalities that all Filestack
# objects can call.
module FilestackCommon
  # Send the delete api request to delete a filelink
  #
  # @param [String]             file_handle   The Filelink handle
  # @param [String]             apikey        Your Filestack API Key
  # @param [FilestackSecurity]  security      Optional Filestack security object
  #                                           if security is enabled.
  #
  # @return [Typhoeus::Response]
  def send_delete(file_handle, apikey, security = nil)
    url = format('%s/file/%s?key=%s',
                 FilestackConfig::API_URL,
                 file_handle,
                 apikey)

    url = security.sign_url(url) unless security.nil?

    Typhoeus.delete(url)
  end

  # Send the overwrite api request to update a filelink
  #
  # @param [String]             filepath      filepath of file to upload
  # @param [String]             file_handle   The Filelink handle
  # @param [String]             apikey        Your Filestack API Key
  # @param [FilestackSecurity]  security      Optional Filestack security object
  #                                           if security is enabled.
  #
  # @return [Typhoeus::Response]
  def send_overwrite(filepath, file_handle, apikey, security = nil)
    url = format('%s/file/%s?key=%s', FilestackConfig::API_URL,
                 file_handle, apikey)
    url = security.sign_url(url) unless security.nil?

    file = File.open(filepath, 'r')
    contents = file.read
    headers = { 'Content-Type' => 'application/octet-stream' }

    request = Typhoeus::Request.new(url, headers: headers,
                                         method: :post,
                                         body: contents)
    request.run
  end
end
