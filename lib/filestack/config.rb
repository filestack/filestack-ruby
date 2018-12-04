require 'filestack/ruby/version'

include Filestack

class FilestackConfig
  API_URL = 'https://www.filestackapi.com/api'.freeze
  CDN_URL = 'https://cdn.filestackcontent.com'.freeze
  PROCESS_URL = 'https://process.filestackapi.com'.freeze

  MULTIPART_START_URL = 'https://upload.filestackapi.com/multipart/start'.freeze
  MULTIPART_UPLOAD_URL = 'https://upload.filestackapi.com/multipart/upload'.freeze
  MULTIPART_COMMIT_URL = 'https://upload.filestackapi.com/multipart/commit'.freeze
  MULTIPART_COMPLETE_URL = 'https://upload.filestackapi.com/multipart/complete'.freeze

  MULTIPART_PARAMS = %w[
    store_location store_region store_container
    store_path store_access
  ].freeze

  DEFAULT_CHUNK_SIZE = 8 * 1024**2
  DEFAULT_OFFSET_SIZE = 1 * 1024**2
  VERSION = Filestack::Ruby::VERSION
  HEADERS = {
    'User-Agent' => "filestack-ruby #{VERSION}",
    'Filestack-Source' => "Ruby-#{VERSION}"
  }.freeze

  INTELLIGENT_ERROR_MESSAGES = ['BACKEND_SERVER', 'BACKEND_NETWORK', 'S3_SERVER', 'S3_NETWORK']
end

class TransformConfig
  TRANSFORMATIONS = %w[
    resize crop rotate flip flop watermark detect_faces
    crop_faces pixelate_faces round_corners vignette polaroid
    torn_edges shadow circle border sharpen blur monochrome
    blackwhite sepia pixelate oil_paint negative modulate
    partial_pixelate partial_blur collage upscale enhance
    redeye ascii filetype_conversion quality urlscreenshot no_metadata
  ].freeze
end
