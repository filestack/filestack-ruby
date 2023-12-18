require 'base64'
require 'timeout'
require 'digest'
require 'mini_mime'
require 'json'
require 'parallel'
require 'typhoeus'
require 'progress_bar'
require 'filestack/config'
require 'filestack/utils/utils'

include UploadUtils
include IntelligentUtils
# Includes all the utility functions for Filestack multipart uploads
module MultipartUploadUtils

  def get_file_attributes(file, options = {})
    filename = options[:filename] || File.basename(file)
    mimetype = options[:mimetype] || get_mimetype_from_file(file) || FilestackConfig::DEFAULT_UPLOAD_MIMETYPE
    filesize = File.size(file)

    [filename, filesize, mimetype.to_s]
  end

  def get_io_attributes(io, options = {})
    filename = options[:filename] || 'unnamed_file'
    mimetype = options[:mimetype] || FilestackConfig::DEFAULT_UPLOAD_MIMETYPE

    io.seek(0, IO::SEEK_END)
    filesize = io.tell

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
  # @param [String]             storage        Default storage to be used for uploads
  # @param [Hash]               options       User-defined options for
  #                                           multipart uploads
  # @param [Bool]               intelligent   Upload file using Filestack Intelligent Ingestion
  #
  # @return [Typhoeus::Response]
  def multipart_start(apikey, filename, filesize, mimetype, security, storage, options = {}, intelligent)
    params = {
      apikey: apikey,
      filename: filename,
      mimetype: mimetype,
      size: filesize,
      store: { location: storage },
      fii: intelligent
    }

    params[:store].merge!(options) if options

    unless security.nil?
      params[:policy] = security.policy
      params[:signature] = security.signature
    end

    response = Typhoeus.post(FilestackConfig.multipart_start_url,
                             body: params.to_json,
                             headers: FilestackConfig::HEADERS)

    if response.code == 200
      JSON.parse(response.body)
    else
      raise RuntimeError.new(response.body)
    end
  end

  # Create array of jobs for parallel uploading
  #
  # @param [String]             apikey         Filestack API key
  # @param [String]             filename       Name of incoming file
  # @param [Int]                filesize       Size of incoming file
  # @param [Typhoeus::Response]  start_response Response body from
  #                                            multipart_start
  # @param [String]             storage        Default storage to be used for uploads
  # @param [Hash]               options        User-defined options for
  #                                            multipart uploads
  #
  # @return [Array]
  def create_upload_jobs(apikey, filename, filesize, start_response, storage, options)
    jobs = []
    part = 1
    seek_point = 0
    while seek_point < filesize
      part_info = {
        seek_point: seek_point,
        filename: filename,
        apikey: apikey,
        part: part,
        filesize: filesize,
        uri: start_response['uri'],
        region: start_response['region'],
        upload_id: start_response['upload_id'],
        location_url: start_response['location_url'],
        start_response: start_response,
        store: { location: storage },
      }

      part_info[:store].merge!(options) if options

      size = if seek_point + FilestackConfig::DEFAULT_CHUNK_SIZE > filesize
        filesize - (seek_point)
      else
        FilestackConfig::DEFAULT_CHUNK_SIZE
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
  # @param [String]             filepath       Location url given back
  #                                            from endpoint
  # @param [StringIO]           io             The IO object
  # @param [Hash]               options        User-defined options for
  #                                            multipart uploads
  # @param [String]             storage        Default storage to be used for uploads
  #
  # @return [Typhoeus::Response]
  def upload_chunk(job, apikey, filepath, io, options, storage)
    file = filepath ? File.open(filepath) : io
    file.seek(job[:seek_point])
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
      store: { location: storage },
    }
    data = data.merge!(options) if options

    fs_response = Typhoeus.post(FilestackConfig.multipart_upload_url(job[:location_url]),
                                body: data.to_json,
                                headers: FilestackConfig::HEADERS).body
    fs_response = JSON.parse(fs_response)
    Typhoeus.put(
      fs_response['url'], headers: fs_response['headers'], body: chunk
    )
  end
  # Runs all jobs in parallel
  #
  # @param [Array]              jobs           Array of jobs to be run
  # @param [String]             apikey         Filestack API key
  # @param [String]             filepath       Local path to file
  # @param [Hash]               options        User-defined options for
  #                                            multipart uploads
  # @param [String]             storage        Default storage to be used for uploads
  #
  # @return [Array]                            Array of parts/etags strings
  def run_uploads(jobs, apikey, filepath, io, options, storage)
    bar = ProgressBar.new(jobs.length)
    results = Parallel.map(jobs, in_threads: 4) do |job|
      response = upload_chunk(
        job, apikey, filepath, io, options, storage
      )
      if response.code == 200
        bar.increment!
        part = job[:part]
        etag = response.headers[:etag]
        { part_number: part, etag: etag }
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
  # @param [Typhoeus::Response]  start_response  Response body from
  #                                             multipart_start
  # @param [FilestackSecurity]  security        Security object with
  #                                             policy/signature
  # @param [Array]              parts_and_etags Array of strings defining
  #                                             etags and their associated
  #                                             part numbers
  # @param [Hash]               options         User-defined options for
  #                                             multipart uploads
  # @param [String]             storage        Default storage to be used for uploads
  # @param [Boolean]            intelligent     Upload file using Filestack Intelligent Ingestion
  #
  # @return [Typhoeus::Response]
  def multipart_complete(apikey, filename, filesize, mimetype, start_response, parts_and_etags, options, storage, intelligent = false)
    data = {
      apikey: apikey,
      uri: start_response['uri'],
      region: start_response['region'],
      upload_id: start_response['upload_id'],
      filename: filename,
      size: filesize,
      mimetype: mimetype,
      store: { location: storage },
    }
    data[:store].merge!(options) if options
    data.merge!(intelligent ? { fii: intelligent } : { parts: parts_and_etags })

    Typhoeus.post(FilestackConfig.multipart_complete_url(start_response['location_url']),
                  body: data.to_json,
                  headers: FilestackConfig::HEADERS)
  end

  # Run entire multipart process through with file and options
  #
  # @param [String]             apikey          Filestack API key
  # @param [String]             filename        Name of incoming file
  # @param [StringIO]           io              The IO object
  # @param [FilestackSecurity]  security        Security object with
  #                                             policy/signature
  # @param [Hash]               options         User-defined options for
  #                                             multipart uploads
  # @param [String]             storage         Default storage to be used for uploads
  # @param [Boolean]            intelligent     Upload file using Filestack Intelligent Ingestion
  #
  # @return [Hash]
  def multipart_upload(apikey, filepath, io, security, options, timeout, storage, intelligent = false)
    filename, filesize, mimetype = if filepath
                                    get_file_attributes(filepath, options)
                                   else
                                    get_io_attributes(io, options)
                                   end

    start_response = multipart_start(
      apikey, filename, filesize, mimetype, security, storage, options, intelligent
    )

    jobs = create_upload_jobs(
      apikey, filename, filesize, start_response, storage, options
    )

    if intelligent
      state = IntelligentState.new
      run_intelligent_upload_flow(jobs, filepath, io, state, storage)
      response_complete = multipart_complete(
        apikey, filename, filesize, mimetype,
        start_response, nil, options, storage, intelligent
      )
    else
      parts_and_etags = run_uploads(jobs, apikey, filepath, io, options, storage)
      response_complete = multipart_complete(
        apikey, filename, filesize, mimetype,
        start_response, parts_and_etags, options, storage
      )
    end
    begin
      Timeout::timeout(timeout) {
        while response_complete.code == 202
          response_complete = multipart_complete(
            apikey, filename, filesize, mimetype,
            start_response, nil, options, storage, intelligent
          )
        end
      }
    rescue StandardError
      raise "Upload timed out upon completion. Please try again later"
    end
    JSON.parse(response_complete.body)
  end

  private

  def get_mimetype_from_file(file)
    file_info = MiniMime.lookup_by_filename(File.open(file))

    file_info ? file_info.content_type : nil
  end
end
