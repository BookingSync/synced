require 'synced/attributes_as_hash'

module Synced
  module DelegateAttributes
    extend ActiveSupport::Concern
    included do
      synced_attributes_as_hash(synced_delegate_attributes).each do |key, value|
        define_method(key) { send(synced_data_key)[value] }
      end
    end

    module ClassMethods
      include Synced::AttributesAsHash
    end
  end
end
