# Provide a serialized attribute for models. This attribute is `synced_data_key`
# which by default is `:synced_data`. This is a friendlier alternative to
# `serialize` with respect to dirty attributes.
module Synced
  module HasSyncedData
    extend ActiveSupport::Concern

    included do
      if synced_data_key
        define_method "#{synced_data_key}=" do |object|
          write_attribute synced_data_key, dump(object)
        end

        define_method synced_data_key do
          instance_variable_get("@#{synced_data_key}") ||
            instance_variable_set("@#{synced_data_key}",
              BookingSync::API::Resource.new(nil, loaded_synced_data))
        end
      end
    end

    private

    def loaded_synced_data
      if data = read_attribute(synced_data_key)
        load data
      else
        {}
      end
    end

    def dump(object)
      JSON.dump object
    end

    def load(source)
      JSON.load source
    end
  end
end
