module Filestack
  # A helper class for the purpose of implementing a symbolize_keys method
  # similar to ActiveSupport's symbolize_keys.
  class Hash

    # Convert a hash to use symbolized keys.
    #
    # @param [Hash]   to_symbolize    The hash which contains the keys to be
    #                                 symbolized
    #
    # @return [Hash]
    def self.symbolize_keys(to_symbolize)
      symbolized = {}
      to_symbolize.each_key do |key|
        symbolized[key.to_sym] = to_symbolize[key]
      end
      symbolized
    end
  end
end
