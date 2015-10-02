module Synced
  module AttributesAsHash
    # On a Hash returns the same Hash
    # On an Array returns a Hash with identical corresponding keys and values
    # Used for mapping local - remote attributes
    def synced_attributes_as_hash(attributes)
      return attributes if attributes.is_a?(Hash)
      Hash[Array.wrap(attributes).map { |name| [name, name] }]
    end
  end
end
