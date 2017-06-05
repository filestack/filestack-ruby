require "filestack/config"
require "typhoeus"

module FilestackCommon
  def send_delete(file_handle, apikey, security = nil)
    url = sprintf("%s/file/%s?key=%s",
      FilestackConfig::API_URL,
      file_handle,
      apikey)

    if !security.nil?
      url = security.sign_url(url)
    end

    response = Typhoeus.delete(url)
    return response
  end

  def send_overwrite(filepath, file_handle, apikey, security = nil)
    url = sprintf("%s/file/%s?key=%s",
      FilestackConfig::API_URL,
      file_handle,
      apikey)

    if !security.nil?
     url = security.sign_url(url)
    end

    file = File.open(filepath,"r")
    contents = file.read

    request = Typhoeus::Request.new(
      url,
      headers: {'Content-Type' => 'application/octet-stream'},
      method: :post,
      body: contents
    )
    response = request.run

    return response
  end
end