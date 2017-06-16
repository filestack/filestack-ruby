require 'base64'
require 'json'
require 'openssl'

#
# This class represents a Filestack Security object that you must passed
# in with your calls if your account has security enabled.  You can manage
# your Filestack app's security and secret by logging into the Filestack
# Dev portal.
#
class FilestackSecurity
  DEFAULT_EXPIRY = 3600

  attr_accessor :policy, :signature

  # Initialize FilestackSecurity object
  #
  # @param [String]   secret    Your filestack security secret
  # @param [Hash]     options   Hash of options:
  #                               call: The calls that you allow this policy to
  #                                 make, e.g convert, exif, pick, read, remove,
  #                                 stat, store, write, writeUrl
  #                               container: (regex) store must match container
  #                                 that the files will be stored under
  #                               expiry: (timestamp) epoch_timestamp expire,
  #                                 defaults to 1hr
  #                               handle: specific file this policy can access
  #                               maxSize: (number) maximum file size in bytes
  #                                 that can be stored by requests with policy
  #                               minSize: (number) minimum file size in bytes
  #                                  that can be stored by requests with policy
  #                               path: (regex) store must match the path that
  #                                  the files will be stored under.
  #                               url: (regex) subset of external URL domains
  #                                  that are allowed to be image/document
  #                                  sources for processing
  def initialize(secret, options: {})
    generate(secret, options)
  end

  # Generate the security policy and signature given a string and options
  #
  # @param [String]   secret    Your filestack security secret
  # @param [Hash]     options   Hash of options - see constructor
  def generate(secret, options)
    policy_json = create_policy_string(options)
    @policy = Base64.urlsafe_encode64(policy_json)
    @signature = OpenSSL::HMAC.hexdigest('sha256', secret, policy)
  end

  # Sign the URL by appending policy and signature URL parameters
  #
  # @param [String]   url    The URL to sign
  #
  # @return [String]
  def sign_url(url)
    format('%s&policy=%s&signature=%s', url, policy, signature)
  end

  private

  #
  # Manage options and convert hash to json string
  #
  def create_policy_string(options)
    options[:expiry] = expiry_timestamp(options)
    options.to_json
  end

  #
  # Get expiration timestamp by adding seconds in option or using default
  #
  def expiry_timestamp(options)
    expiry_time = if options.key?(:expiry)
                    options[:expiry]
                  else
                    FilestackSecurity::DEFAULT_EXPIRY
                  end

    Time.now.to_i + expiry_time
  end
end
