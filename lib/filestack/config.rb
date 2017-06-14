require 'filestack/ruby/version'

include Filestack

class FilestackConfig
  API_URL = 'https://www.filestackapi.com/api'.freeze
  CDN_URL = 'https://cdn.filestackcontent.com'.freeze
  PROCESS_URL = 'https://process.filestackapi.com'.freeze

  MULTIPART_START_URL = 'https://upload.filestackapi.com/multipart/start'.freeze
  MULTIPART_UPLOAD_URL = 'https://upload.filestackapi.com/multipart/upload'.freeze
  MULTIPART_COMPLETE_URL = 'https://upload.filestackapi.com/multipart/complete'.freeze

  MULTIPART_PARAMS = %w[
    store_location store_region store_container
    store_path store_access
  ].freeze

  DEFAULT_CHUNK_SIZE = 5 * 1024**2
  VERSION = Filestack::Ruby::VERSION
  HEADERS = {
    'User-Agent' => "filestack-python #{VERSION}",
    'Filestack-Source' => "Ruby-#{VERSION}"
  }.freeze
end
