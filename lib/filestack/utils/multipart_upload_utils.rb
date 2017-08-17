require 'base64'
require 'digest'
require 'mimemagic'
require 'json'
require 'parallel'
require 'unirest'
require 'progress_bar'
require 'filestack/config'
require 'filestack/utils/utils'

include UploadUtils
include IntelligentUtils
Unirest.timeout(30)
# Includes all the utility functions for Filestack multipart uploads
module MultipartUploadUtils
  def get_file_info(file)
    filename = File.basename(file)
    filesize = File.size(file)
    mimetype = MimeMagic.by_magic(File.open(file))
    if mimetype.nil?
      mimetype = 'application/octet-stream'
    end
    [filename, filesize, mimetype.to_s]
  end

  # Send start response to multipart endpoint
  #
  # @param [String]             apikey        Filestack API key
  # @param [String]             filename      Name of incoming file
  # @param [Int]                filesize      Size of incoming file
  # @param [String]             mimetype      Mimetype of incoming file
  # @param [FilestackSecurity]  security      Security object with
  #                                           policy/signature
  # @param [Hash]               options       User-defined options for
  #                                           multipart uploads
  #
  # @return [Unirest::Response]
  def multipart_start(apikey, filename, filesize, mimetype, security, options)
    params = {
      apikey: apikey,
      filename: filename,
      mimetype: mimetype,
      size: filesize,
      store_location: options.nil? ? 's3' : options[:store_location],
      file: Tempfile.new(filename),
      options: options,
      'multipart' => 'true'
    }
    params = params.merge!(options) if options

    unless security.nil?
      params[:policy] = security.policy
      params[:signature] = security.signature
    end

    response = Unirest.post(
      FilestackConfig::MULTIPART_START_URL, parameters: params,
                                            headers: FilestackConfig::HEADERS
    )
    if response.code == 200
      response.body
    else
      raise RuntimeError.new(response.body)
    end
  end

  # Create array of jobs for parallel uploading
  #
  # @param [String]             apikey         Filestack API key
  # @param [String]             filename       Name of incoming file
  # @param [String]             filepath       Local path to file
  # @param [Int]                filesize       Size of incoming file
  # @param [Unirest::Response]  start_response Response body from
  #                                            multipart_start
  # @param [Hash]               options        User-defined options for
  #                                            multipart uploads
  #
  # @return [Array]
  def create_upload_jobs(apikey, filename, filepath, filesize, start_response, options)
    jobs = []
    part = 1
    seek_point = 0
    while seek_point < filesize
      part_info = {
        seek: seek_point,
        filepath: filepath,
        filename: filename,
        apikey: apikey,
        part: part,
        filesize: filesize,
        uri: start_response['uri'],
        region: start_response['region'],
        upload_id: start_response['upload_id'],
        location_url: start_response['location_url'],
        start_response: start_response,
        options: options,
        store_location: options.nil? ? 's3' : options[:store_location]
      }
      if seek_point + FilestackConfig::DEFAULT_CHUNK_SIZE > filesize
        size = filesize - (seek_point)
      else
        size = FilestackConfig::DEFAULT_CHUNK_SIZE
      end
      part_info[:size] = size
      jobs.push(part_info)
      part += 1
      seek_point += FilestackConfig::DEFAULT_CHUNK_SIZE
    end
    jobs
  end

 
  # Uploads one chunk of the file
  #
  # @param [Hash]               job            Hash of options needed
  #                                            to upload a chunk
  # @param [String]             apikey         Filestack API key
  # @param [String]             location_url   Location url given back
  #                                            from endpoint
  # @param [String]             filepath       Local path to file
  # @param [Hash]               options        User-defined options for
  #                                            multipart uploads
  #
  # @return [Unirest::Response]
  def upload_chunk(job, apikey, filepath, options)
    file = File.open(filepath)
    file.seek(job[:seek])
    chunk = file.read(FilestackConfig::DEFAULT_CHUNK_SIZE)
    
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
      file: Tempfile.new(job[:filename])
    }
    data = data.merge!(options) if options
    fs_response = Unirest.post(
      FilestackConfig::MULTIPART_UPLOAD_URL, parameters: data,
                                             headers: FilestackConfig::HEADERS
    ).body
    Unirest.put(
      fs_response['url'], headers: fs_response['headers'], parameters: chunk
    )
  end
  # Runs all jobs in parallel
  #
  # @param [Array]              jobs           Array of jobs to be run
  # @param [String]             apikey         Filestack API key
  # @param [String]             filepath       Local path to file
  # @param [Hash]               options        User-defined options for
  #                                            multipart uploads
  #
  # @return [Array]                            Array of parts/etags strings
  def run_uploads(jobs, apikey, filepath, options)
    bar = ProgressBar.new(jobs.length)
    results = Parallel.map(jobs, in_threads: 4) do |job|
      response = upload_chunk(
        job, apikey, filepath, options
      )
      if response.code == 200 
        bar.increment!
        part = job[:part]
        etag = response.headers[:etag]
        "#{part}:#{etag}"
      end
    end
    results
  end
  # Send complete call to multipart endpoint
  #
  # @param [String]             apikey          Filestack API key
  # @param [String]             filename        Name of incoming file
  # @param [Int]                filesize        Size of incoming file
  # @param [String]             mimetype        Mimetype of incoming file
  # @param [Unirest::Response]  start_response  Response body from
  #                                             multipart_start
  # @param [FilestackSecurity]  security        Security object with
  #                                             policy/signature
  # @param [Array]              parts_and_etags Array of strings defining
  #                                             etags and their associated
  #                                             part numbers
  # @param [Hash]               options         User-defined options for
  #                                             multipart uploads
  #
  # @return [Unirest::Response]
  def multipart_complete(apikey, filename, filesize, mimetype, start_response, parts_and_etags, options, intelligent = false)
    if !intelligent
      data = {
        apikey: apikey,
        uri: start_response['uri'],
        region: start_response['region'],
        upload_id: start_response['upload_id'],
        filename: filename,
        size: filesize,
        mimetype: mimetype,
        parts: parts_and_etags.join(';'),
        store_location: options.nil? ? 's3' : options[:store_location],
        file: Tempfile.new(filename)
      }
    else
      data = {
        apikey: apikey,
        uri: start_response['uri'],
        region: start_response['region'],
        upload_id: start_response['upload_id'],
        filename: filename,
        size: filesize,
        mimetype: mimetype,
        store_location: options.nil? ? 's3' : options[:store_location],
        file: Tempfile.new(filename),
        'multipart' => 'true'
      }
    end
    data = data.merge!(options) if options

    Unirest.post(
      FilestackConfig::MULTIPART_COMPLETE_URL, parameters: data,
                                               headers: FilestackConfig::HEADERS
    )
  end

  # Run entire multipart process through with file and options
  #
  # @param [String]             apikey          Filestack API key
  # @param [String]             filename        Name of incoming file
  # @param [FilestackSecurity]  security        Security object with
  #                                             policy/signature
  # @param [Hash]               options         User-defined options for
  #                                             multipart uploads
  #
  # @return [Unirest::Response]
  def multipart_upload(apikey, filepath, security, options, timeout, intelligent: false)
    filename, filesize, mimetype = get_file_info(filepath)
    start_response = multipart_start(
      apikey, filename, filesize, mimetype, security, options
    )
    unless start_response['upload_type'].nil?
      intelligent_enabled = ((start_response['upload_type'].include? 'intelligent_ingestion')) && intelligent
    end
    jobs = create_upload_jobs(
      apikey, filename, filepath, filesize, start_response, options
    )
    if intelligent_enabled
      state = IntelligentState.new
      run_intelligent_upload_flow(jobs, state)
      response_complete = multipart_complete(
        apikey, filename, filesize, mimetype,
        start_response, nil, options, intelligent
      )
    else
      parts_and_etags = run_uploads(jobs, apikey, filepath, options)
      response_complete = multipart_complete(
        apikey, filename, filesize, mimetype,
        start_response, parts_and_etags, options
      )
    end
    begin
      Timeout::timeout(timeout){
        while response_complete.code == 202
          response_complete = multipart_complete(
            apikey, filename, filesize, mimetype,
            start_response, nil, options, intelligent
          )      
        end
      }
    rescue
      raise "Upload timed out upon completion. Please try again later"
    end
    response_complete.body
  end
end
