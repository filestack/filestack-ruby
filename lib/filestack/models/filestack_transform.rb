require 'filestack/config'
require 'filestack/models/filestack_av'

# Class for creating transformation chains and storing them to Filestack
class Transform
  include TransformUtils
  attr_reader :handle, :external_url, :security

  def initialize(handle: nil, external_url: nil, security: nil, apikey: nil)
    @apikey = apikey
    @handle = handle
    @external_url = external_url
    @security = security
    @transform_tasks = []
  end

  # Catches method calls and checks to see if they exist in transformation list
  #
  # This is to avoid rewriting the same code
  # over and over for transform chaining
  #
  # @return [Filestack::Transform] or Error
  def method_missing(method_name, **args)
    if TransformConfig::TRANSFORMATIONS.include? method_name.to_s
      @transform_tasks.push(
        add_transform_task(method_name, args)
      )
      self
    else
      super
    end
  end

  # Converts one filetype to the other
  #
  # @param options
  #
  # @return [Filestack::Transform]
  def filetype_conversion(options)
    @transform_tasks.push(
      add_transform_task('output', options)
    )
    self
  end

  # Converts video or audio based on user-provided parameters
  #
  # @param [Hash]              options        User-provided parameters
  #
  # @return [Filestack::AV]
  def av_convert(options)
    if @external_url
      return 'av_convert does not support external URLs. Please upload file first.'
    end
    @transform_tasks.push(
      add_transform_task('video_convert', options)
    )
    response = UploadUtils.make_call(url, 'post')
    if response.code == 200
      return AV.new(url, apikey: @apikey, security: @security)
    end
    response.body
  end

  # Add debug parameter to get information on transformation image
  #
  # @return [Unirest::Response]
  def debug
    @transform_tasks.push(
      add_transform_task('debug')
    )
    UploadUtils.make_call(url, 'get').body
  end

  # Stores a transformation URL and returns a filelink
  #
  # @return [Filestack::FilestackFilelink]
  def store
    @transform_tasks.push(
      add_transform_task('store', {})
    )
    response = UploadUtils.make_call(url, 'get')
    handle = response.body['url'].split('/').last
    FilestackFilelink.new(handle, apikey: @apikey, security: @security)
  end

  # Override default method (best practice when overriding method_missing)
  def respond_to_missing?(method_name, *)
    TransformConfig::TRANSFORMATIONS.include?(method_name.to_s || super)
  end

  # Creates a URL based on transformation instance state
  #
  # @return [String]
  def url
    base = [FilestackConfig::CDN_URL]
    if @transform_tasks.include? 'debug'
      @transform_tasks.delete('debug')
      base.push('debug')
    end
    base.push(@apikey) if @apikey && @external_url
    if @security
      policy = @security.policy
      signature = @security.signature
      security_string = "security=policy:#{policy},signature:#{signature}"
      base.push(security_string)
    end
    base += @transform_tasks
    base.push(@handle || @external_url)
    base.join('/')
  end
end
