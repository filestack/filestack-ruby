require 'base64'
require 'digest'
require 'mimemagic'
require 'json'
require 'unirest'

require 'filestack/config'

# Includes general utility functions for the Filestack Ruby SDK
module UploadUtils
  # General request function
  # @param [String]           url          The URL being called
  # @param [String]           action       The specific HTTP action
  #                                        ('get', 'post', 'delete', 'put')
  # @param [Hash]             parameters   The query and/or body parameters
  #
  # @return [Unirest::Request]
  def make_call(url, action, parameters: nil, headers: nil)
    headers = if headers
                headers.merge!(FilestackConfig::HEADERS)
              else
                FilestackConfig::HEADERS
              end
    Unirest.public_send(
      action, url, parameters: parameters, headers: headers
    )
  end

  # Uploads to v1 REST API (for external URLs or if multipart is turned off)
  #
  # @param [String]             apikey         Filestack API key
  # @param [String]             filepath       Local path to file
  # @param [String]             external_url   External URL to be uploaded
  # @param [FilestackSecurity]  security       Security object with
  #                                            policy/signature
  # @param [Hash]               options        User-defined options for
  #                                            multipart uploads
  # @param [String]             storage        Storage destination
  #                                            (s3, rackspace, etc)
  # @return [Unirest::Response]
  def send_upload(apikey, filepath: nil, external_url: nil, security: nil, options: nil, storage: 'S3')
    data = if filepath
             { fileUpload: File.open(filepath) }
           else
             { url: external_url }
           end

    # adds any user-defined upload options to request payload
    data = data.merge!(options) unless options.nil?
    base = "#{FilestackConfig::API_URL}/store/#{storage}?key=#{apikey}"

    if security
      policy = security.policy
      signature = security.signature
      base = "#{base}&signature=#{signature}&policy=#{policy}"
    end

    response = make_call(base, 'post', parameters: data)
    if response.code == 200
      handle = response.body['url'].split('/').last
      return { 'handle' => handle }
    end
    raise response.body
  end

  # Generates the URL for a FilestackFilelink object
  # @param [String]           base          The base Filestack URL
  # @param [String]           handle        The FilestackFilelink handle (optional)
  # @param [String]           path          The specific API path (optional)
  # @param [String]           security      Security for the FilestackFilelink (optional)
  #
  # return [String]
  def get_url(base, handle: nil, path: nil, security: nil)
    url_components = [base]

    url_components.push(path) unless path.nil?
    url_components.push(handle) unless handle.nil?
    url = url_components.join('/')

    if security
      policy = security.policy
      signature = security.signature
      security_path = "policy=#{policy}&signature=#{signature}"
      url = "#{url}?#{security_path}"
    end
    url
  end
end

# Utility functions for transformations
module TransformUtils
  # Creates a transformation task to be sent back to transform object
  #
  # @return [String]
  def add_transform_task(transform, options = {})
    options_list = []
    if !options.empty?
      options.each do |key, array|
        options_list.push("#{key}:#{array}")
      end
      options_string = options_list.join(',')
      "#{transform}=#{options_string}"
    else
      transform.to_s
    end
  end
end
