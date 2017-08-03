require 'base64'
require 'digest'
require 'fiber'
require 'mimemagic'
require 'json'
require 'unirest'

require 'filestack/config'
# set timeout for all requests to be 30 seconds
Unirest.timeout(30)
class IntelligentState
  attr_accessor :offset, :ok, :error_type
  def initialize
    @offset = 524288
    @ok = true
    @alive = true
    @retries = 1
    @backoff = 5
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
    @backoff
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

  # Generates the URL for a Filelink object
  # @param [String]           base          The base Filestack URL
  # @param [String]           handle        The Filelink handle (optional)
  # @param [String]           path          The specific API path (optional)
  # @param [String]           security      Security for the Filelink (optional)
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
  # @param     generator     A living Fiber object
  #
  # @return [Array]
  def get_generator_batch(generator)
    batch = []
    4.times do
      batch.push(generator.resume) if generator.alive?
    end
    return batch
  end

  def bad_state(state)
    !state.ok && state.alive?
  end

  def change_offset(working_offset, state)
    if state.offset > working_offset
      working_offset
    else
      state.offset
    end
  end
  # Runs the intelligent upload flow, from start to finish
  #
  # @param     jobs      A list of file parts
  # @param     state     An IntelligentState object
  #
  # @return [Array]
  def run_intelligent_upload_flow(jobs, state)
    bar = ProgressBar.new(jobs.length)
    generator = create_intelligent_generator(jobs)
    working_offset = FilestackConfig::DEFAULT_OFFSET_SIZE
    while generator.alive?
      batch = get_generator_batch(generator)      
      Parallel.map(batch, in_threads: 5) do |chunk|
        response, state = run_intelligent_uploads(chunk, state)
        # condition: chunk did not fail and has been committed 
          # condition: a chunk has failed but we have not reached the maximum retries
        while bad_state(state)
          # condition: timeout to S3, requiring offset size to be changed
          if state.error_type == 'S3'
            sleep(state.backoff)
            state.offset = working_offset = change_offset(working_offset, state)
          # condition: timeout to backend, requiring only backoff
          elsif state.error_type == 'BACKEND'
            sleep(state.backoff)
          end
          state.add_retry
          response, state = run_intelligent_uploads(chunk, state)
        end
        unless state.ok
          raise "Upload has failed. Please try again later."
        end
        bar.increment!
      end
    end
  end

  def create_intelligent_generator(jobs)
    jobs_gen = jobs.lazy.each
    Fiber.new do
      (jobs.length-1).times do 
        Fiber.yield jobs_gen.next
      end
      jobs_gen.next
    end
  end

   def create_upload_job_chunks(jobs, state, apikey, filename, filepath, filesize, start_response, options)
    intelligent_list = []
    jobs.each { |job|
      job[:chunks] = chunk_job(
        job, state, apikey, filename, filepath, filesize, start_response, options
      )
    }
    jobs
  end

  def chunk_job(job, state, apikey, filename, filepath, filesize, start_response, options)
    offset = 0
    seek_point = job[:seek]
    chunk_list = []
    while (offset < FilestackConfig::DEFAULT_CHUNK_SIZE) && (seek_point + offset) < filesize
      chunk_list.push(
        seek: seek_point,
        filepath: filepath,
        filename: filename,
        apikey: apikey,
        part: job[:part],
        size: job[:size],
        uri: start_response['uri'],
        region: start_response['region'],
        upload_id: start_response['upload_id'],
        location_url: start_response['location_url'],
        store_location: job[:store_location],
        offset: offset
      )
      offset += state.offset
    end
    chunk_list
  end

  def run_intelligent_uploads(part, state)
    failed = false
    chunks = chunk_job(
      part, state, part[:apikey], part[:filename], part[:filepath], 
      part[:filesize], part[:start_response], part[:options]
    )
    chunk_results = Parallel.map(chunks, in_threads: 3) do |chunk|
      begin
        upload_chunk_intelligently(chunk, state, part[:apikey], part[:filepath], part[:options])
      rescue => e
        if e.message == 'S3' or e.message == 'BACKEND'
          state.error_type = e.message
        end
        failed = true
        Parallel::Kill
      end
    end

    if failed
      state.ok = false
      return false, state
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
      location_url: part[:location_url],
      store_location: part[:store_location],
      file: Tempfile.new(part[:filename])
    }
    response = Unirest.post(FilestackConfig::MULTIPART_COMMIT_URL, parameters: commit_params,
                                                                   headers: FilestackConfig::HEADERS)
    if response.code == 200
      state.reset
      return [response, state]
    else 
      state.ok = false
      return [response, state]
    end
  end

  def upload_chunk_intelligently(job, state, apikey, filepath, options)
    file = File.open(filepath)
    file.seek(job[:seek] + job[:offset])
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
      store_location: job[:store_location],
      offset: job[:offset],
      file: Tempfile.new(job[:filename]),
      'multipart' => 'true'
    }

    data = data.merge!(options) if options
    fs_response = Unirest.post(
      FilestackConfig::MULTIPART_UPLOAD_URL, parameters: data,
                                              headers: FilestackConfig::HEADERS
    )
    begin 
      if fs_response.code == 200
        fs_response = fs_response.body
      elsif fs_response.code == 500
        raise 'BACKEND'
      else 
        raise 'FAILURE'
      end

    rescue
      raise 'BACKEND'
    end

    begin 
      amazon_response = Unirest.put(
        fs_response['url'], headers: fs_response['headers'], parameters: chunk
      )
      unless amazon_response.code == 200
        if amazon_response.code == 500
          raise 'S3'
        else 
          raise 'FAILURE'
        end
      end
    
    rescue
      raise 'S3'
    end
    amazon_response
  end
end
