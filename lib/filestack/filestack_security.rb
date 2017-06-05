require "base64"
require 'openssl'

class FilestackSecurity

  DEFAULT_EXPIRY = 3600
  attr_accessor :policy, :signature

  def initialize(secret, options = {})
    self.generate(secret, options);
  end

  def generate(secret, options)
    expiry_time = if options.key?(:expiry) then
      options["expiry"]
    else
      FilestackSecurity::DEFAULT_EXPIRY
    end

    expiration_timestamp = Time.now.to_i + expiry_time

    policy_json = '{"expiry": "' + expiration_timestamp.to_s + '"}'

    self.policy = Base64.urlsafe_encode64(policy_json)
    self.signature = OpenSSL::HMAC.hexdigest('sha256', secret, self.policy)
  end

  def sign_url(url)
    return sprintf("%s&policy=%s&signature=%s",
      url, self.policy, self.signature)
  end
end