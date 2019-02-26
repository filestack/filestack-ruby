require 'filestack/models/filelink'
require 'filestack/utils/utils'
require 'json'

# Class for AV objects -- allows to check status
# and upgrade to filelink once completed
class AV
  include UploadUtils
  attr_reader :apikey, :security

  def initialize(url, apikey: nil, security: nil)
    @url = url
    @apikey = apikey
    @security = security
  end

  # Turns AV into filelink if video conversion is complete
  #
  # @return [Filestack::FilestackFilelink]
  def to_filelink
    filelink_from_response('url')
  end
    
  # Returns filelink of the video thumbnail
  # if video conversion is complete
  #
  # @return [Filestack::FilestackFilelink]
  def thumbnail
    filelink_from_response('thumb')
  end

  # Checks the status of the video conversion
  #
  # @return [String]
  def status
    response = UploadUtils.make_call(@url, 'get')
    response_body = JSON.parse(response.body)
    response_body['status']
  end
  
  private 

  # Turns a data property into a filelink
  # if video conversion is complete
  #
  # @return [Filestack::FilestackFilelink]
  def filelink_from_response(property)
    return 'Video conversion incomplete' unless status == 'completed'
    response = UploadUtils.make_call(@url, 'get')
    response_body = JSON.parse(response.body)
    handle = response_body['data'][property.to_s].split('/').last
    FilestackFilelink.new(handle, apikey: @apikey, security: @security)
  end
end
