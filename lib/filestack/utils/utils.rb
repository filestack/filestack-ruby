require 'base64'
require 'digest'
require 'fiber'
require 'mini_mime'
require 'json'
require 'typhoeus'

require 'filestack/config'
class IntelligentState
  attr_accessor :offset, :ok, :error_type
  def initialize
    @offset = 524288
    @ok = true
    @alive = true
    @retries = 0
    @backoff = 1
    @offset_index = 0
    @offset_sizes = [524288, 262144, 131072, 65536, 32768]
  end

  def alive?
    @alive
  end

  def add_retry
    @retries += 1
    @alive = false if @retries >= 5
  end

  def backoff
    @backoff = 2 ** @retries
  end

  def next_offset
    current_offset = @offset_sizes[@offset_index]
    @offset_index += 1
    return current_offset
  end

  def reset
    @retries = 0
  end
end

# Includes general utility functions for the Filestack Ruby SDK
module UploadUtils
  # General request function
  # @param [String]           url          The URL being called
  # @param [String]           action       The specific HTTP action
  #                                        ('get', 'post', 'delete', 'put')
  # @param [Hash]             parameters   The query and/or body parameters
  #
  # @return [Typhoeus::Request]
  def make_call(url, action, parameters: nil, headers: nil)
    headers = if headers
                headers.merge!(FilestackConfig::HEADERS)
              else
                FilestackConfig::HEADERS
              end
    Typhoeus.public_send(
      action, URI::Parser.new.escape(url), params: parameters, headers: headers
    )
  end

  def build_store_task(options = {})
    return 'store' if options.nil? || options.empty?
    tasks = []
    options.each do |key, value|
      value = case key
              when :workflows
                [value.join('","')]
              when :path
                "\"#{value}\""
              else
                value
              end
      tasks.push("#{key}:#{value.to_s.downcase}")
    end
    "store=#{tasks.join(',')}"
  end

  # Uploads to v1 REST API (for external URLs or if multipart is turned off)
  #
  # @param [String]             apikey         Filestack API key
  # @param [String]             external_url   External URL to be uploaded
  # @param [FilestackSecurity]  security       Security object with
  #                                            policy/signature
  # @param [Hash]               options        User-defined options for
  #                                            multipart uploads
  # @return [Hash]
  def send_upload(apikey, external_url = nil, security = nil, options = nil)
    base = "#{FilestackConfig::CDN_URL}/#{apikey}/#{build_store_task(options)}"

    if security
      policy = security.policy
      signature = security.signature
      base = "#{base}/security=s:#{signature},p:#{policy}"
    end

    response = Typhoeus.post("#{base}/#{external_url}", headers: FilestackConfig::HEADERS)

    if response.code == 200
      begin
        response_body = JSON.parse(response.body)
        return response_body
      rescue
        raise response.body
      end
    end
    raise response.body
  end

  # Generates the URL for a FilestackFilelink object
  # @param [String]           base          The base Filestack URL
  # @param [String]           handle        The FilestackFilelink handle (optional)
  # @param [String]           path          The specific API path (optional)
  # @param [String]           security      Security for the FilestackFilelink (optional)
  #
  # @return [String]
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
  # @param [String]   transform     The task to be added
  # @param [Dict]   options         A dictionary representing the options for that task
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

module IntelligentUtils
  # Generates a batch given a Fiber
  #
  # @param [Fiber]    generator     A living Fiber object
  #
  # @return [Array]
  def get_generator_batch(generator)
    batch = []
    4.times do
      batch.push(generator.resume) if generator.alive?
    end
    return batch
  end

  # Check if state is in error state
  # or has reached maximum retries
  #
  # @param [IntelligentState]  state   An IntelligentState object
  #
  # @return [Boolean]
  def bad_state(state)
    !state.ok && state.alive?
  end

  # Return current working offest if state
  # has not tried it. Otherwise, return the next
  # offset of the state
  #
  # @param [Integer]    working_offset    The current offset
  # @param [IntelligentState]    state    An IntelligentState object
  #
  # @return [Integer]
  def change_offset(working_offset, state)
    if state.offset > working_offset
      working_offset
    else
      state.offset = state.next_offset
    end
  end

  # Runs the intelligent upload flow, from start to finish
  #
  # @param [Array]    jobs      A list of file parts
  # @param [IntelligentState]    state     An IntelligentState object
  #
  # @return [Array]
  def run_intelligent_upload_flow(jobs, filepath, io, state, storage)
    bar = ProgressBar.new(jobs.length)
    generator = create_intelligent_generator(jobs)
    working_offset = FilestackConfig::DEFAULT_OFFSET_SIZE
    while generator.alive?
      batch = get_generator_batch(generator)
      # run parts
      Parallel.map(batch, in_threads: 4) do |part|
        state = run_intelligent_uploads(part, filepath, io, state, storage)
        # condition: a chunk has failed but we have not reached the maximum retries
        while bad_state(state)
          # condition: timeout to S3, requiring offset size to be changed
          if state.error_type == 'S3_NETWORK'
            sleep(5)
            state.offset = working_offset = change_offset(working_offset, state)
          # condition: timeout to backend, requiring only backoff
          elsif ['S3_SERVER', 'BACKEND_SERVER'].include? state.error_type
            sleep(state.backoff)
          end
          state.add_retry
          state = run_intelligent_uploads(part, filepath, io, state, storage)
        end
        raise "Upload has failed. Please try again later." unless state.ok
        bar.increment!
      end
    end
  end

  # Creates a generator of part jobs
  #
  # @param [Array]     jobs      A list of file parts
  #
  # @return [Fiber]
  def create_intelligent_generator(jobs)
    jobs_gen = jobs.lazy.each
    Fiber.new do
      (jobs.length-1).times do
        Fiber.yield jobs_gen.next
      end
      jobs_gen.next
    end
  end

  # Loop and run chunks for each offset
  #
  # @param [Array]              jobs            A list of file parts
  # @param [IntelligentState]   state           An IntelligentState object
  # @param [String]             apikey          Filestack API key
  # @param [String]             filename        Name of incoming file
  # @param [String]             filepath        Local path to the file
  # @param [Int]                filesize        Size of incoming file
  # @param [Typhoeus::Response]  start_response  Response body from
  #                                             multipart_start
  #
  # @return [Array]
  def create_upload_job_chunks(jobs, state, apikey, filename, filepath, filesize, start_response)
    jobs.each { |job|
      job[:chunks] = chunk_job(
        job, state, apikey, filename, filepath, filesize, start_response
      )
    }
    jobs
  end

  # Chunk a specific job into offests
  #
  # @param [Dict]               job             Dictionary with all job options
  # @param [IntelligentState]   state           An IntelligentState object
  # @param [String]             apikey          Filestack API key
  # @param [String]             filename        Name of incoming file
  # @param [String]             filepath        Local path to the file
  # @param [Int]                filesize        Size of incoming file
  # @param [Typhoeus::Response]  start_response  Response body from
  #                                             multipart_start
  #
  # @return [Dict]
  def chunk_job(job, state, apikey, filename, filesize, start_response, storage)
    offset = 0
    seek_point = job[:seek_point]
    chunk_list = []

    while (offset < FilestackConfig::DEFAULT_CHUNK_SIZE) && (seek_point + offset) < filesize
      chunk_list.push(
        seek_point: seek_point,
        filename: filename,
        apikey: apikey,
        part: job[:part],
        size: job[:size],
        uri: start_response['uri'],
        region: start_response['region'],
        upload_id: start_response['upload_id'],
        location_url: start_response['location_url'],
        store: { location: storage },
        offset: offset
      )
      offset += state.offset
    end
    chunk_list
  end

  # Send a job's chunks in parallel and commit
  #
  # @param [Dict]    part      A dictionary representing the information
  #                            for a single part
  # @param [IntelligentState]  state     An IntelligentState object
  #
  # @return [IntelligentState]
  def run_intelligent_uploads(part, filepath, io, state, storage)
    failed = false
    chunks = chunk_job(
      part, state, part[:apikey], part[:filename], part[:filesize], part[:start_response], storage
    )
    Parallel.map(chunks, in_threads: 3) do |chunk|
      begin
        upload_chunk_intelligently(chunk, state, part[:apikey], filepath, io, part[:options], storage)
      rescue => e
        state.error_type = e.message
        failed = true
        Parallel::Kill
      end
    end

    if failed
      state.ok = false
      return state
    else
      state.ok = true
    end

    commit_params = {
      apikey: part[:apikey],
      uri: part[:uri],
      region: part[:region],
      upload_id: part[:upload_id],
      size: part[:filesize],
      part: part[:part],
      location_url: part[:start_response]['location_url'],
      store: { location: storage }
    }

    response = Typhoeus.post(FilestackConfig.multipart_commit_url(commit_params[:location_url]),
                             body: commit_params.to_json,
                             headers: FilestackConfig::HEADERS)

    if response.code == 200
      state.reset
    else
      state.ok = false
    end
    state
  end

  # Upload a single chunk
  #
  # @param [Dict]               job             Dictionary with all job options
  # @param [IntelligentState]   state           An IntelligentState object
  # @param [String]             apikey          Filestack API key
  # @param [String]             filename        Name of incoming file
  # @param [String]             filepath        Local path to the file
  # @param [Hash]               options         User-defined options for
  #                                             multipart uploads
  #
  # @return [Typhoeus::Response]
  def upload_chunk_intelligently(job, state, apikey, filepath, io, options, storage)
    file = filepath ? File.open(filepath) : io
    file.seek(job[:seek_point] + job[:offset])

    chunk = file.read(state.offset)
    md5 = Digest::MD5.new
    md5 << chunk
    data = {
      apikey: apikey,
      part: job[:part],
      size: chunk.length,
      md5: md5.base64digest,
      uri: job[:uri],
      region: job[:region],
      upload_id: job[:upload_id],
      store: { location: storage },
      offset: job[:offset],
      fii: true
    }

    data = data.merge!(options) if options

    fs_response = Typhoeus.post(FilestackConfig.multipart_upload_url(job[:location_url]),
                                body: data.to_json,
                                headers: FilestackConfig::HEADERS)

    # POST to multipart/upload
    begin
      unless fs_response.code == 200
        if [400, 403, 404].include? fs_response.code
          raise 'FAILURE'
        else
          raise 'BACKEND_SERVER'
        end
      end

    rescue
      raise 'BACKEND_NETWORK'
    end
    fs_response = JSON.parse(fs_response.body)

    # PUT to S3
    begin
      amazon_response = Typhoeus.put(
        fs_response['url'], headers: fs_response['headers'], body: chunk
      )
      unless amazon_response.code == 200
        if [400, 403, 404].include? amazon_response.code
          raise 'FAILURE'
        else
          raise 'S3_SERVER'
        end
      end

    rescue
      raise 'S3_NETWORK'
    end
    amazon_response
  end
end
