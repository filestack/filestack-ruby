require 'filestack/ruby/version'

include Filestack

class FilestackConfig
  API_URL = 'https://www.filestackapi.com/api'.freeze
  CDN_URL = 'https://cdn.filestackcontent.com'.freeze
  PROCESS_URL = 'https://process.filestackapi.com'.freeze

  MULTIPART_PARAMS = %w[
    store_location store_region store_container
    store_path store_access
  ].freeze

  DEFAULT_CHUNK_SIZE = 8 * 1024**2
  DEFAULT_OFFSET_SIZE = 1 * 1024**2
  VERSION = Filestack::Ruby::VERSION
  HEADERS = {
    'User-Agent' => "filestack-ruby #{VERSION}",
    'Filestack-Source' => "Ruby-#{VERSION}",
    'Content-Type' => "application/json",
    'Accept-Encoding' => "application/json"
  }.freeze

  INTELLIGENT_ERROR_MESSAGES = ['BACKEND_SERVER', 'BACKEND_NETWORK', 'S3_SERVER', 'S3_NETWORK']

  def self.multipart_start_url
    "https://upload.filestackapi.com/multipart/start"
  end

  def self.multipart_upload_url(base_url)
    "https://#{base_url}/multipart/upload"
  end

  def self.multipart_commit_url(base_url)
    "https://#{base_url}/multipart/commit"
  end

  def self.multipart_complete_url(base_url)
    "https://#{base_url}/multipart/complete"
  end
end

class TransformConfig
  TRANSFORMATIONS = %w[
    resize crop rotate flip flop watermark detect_faces
    crop_faces pixelate_faces rounded_corners vignette polaroid
    torn_edges shadow circle border sharpen blur monochrome
    blackwhite sepia pixelate oil_paint negative modulate
    partial_pixelate partial_blur collage upscale enhance
    redeye ascii filetype_conversion quality urlscreenshot
    no_metadata fallback pdfinfo pdfconvert cache auto_image
    minify_js minify_css animate video_convert video_playlist
    compress content
  ].freeze
end
