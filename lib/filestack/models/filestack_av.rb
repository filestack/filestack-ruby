require 'filestack/models/filelink'
require 'filestack/utils/utils'

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
    return 'Video conversion incomplete' unless status == 'completed'
    response = UploadUtils.make_call(@url, 'get').body
    handle = response['data']['url'].split('/').last
    FilestackFilelink.new(handle, apikey: @apikey, security: @security)
  end

  # Checks the status of the video conversion
  #
  # @return [String]
  def status
    UploadUtils.make_call(@url, 'get').body['status']
  end
end
