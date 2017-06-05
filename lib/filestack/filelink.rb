require "filestack/ruby/version"
require "filestack/mixins/filestack_common"

class Filelink
  include FilestackCommon
  attr_accessor :file_handle, :apikey, :security

  def initialize(file_handle, apikey, security = nil)
    @file_handle = file_handle
    @apikey = apikey
    @security = security
  end

  def delete()
    return self.send_delete(self.file_handle, self.apikey, self.security)
  end

  def overwrite(filepath)
    return self.send_overwrite(filepath, self.file_handle, self.apikey, self.security)
  end
end
