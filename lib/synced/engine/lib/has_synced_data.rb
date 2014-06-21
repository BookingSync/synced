require 'hashie'

module Synced
  # Provide a serialized `bs_data` attribute for models. This is a friendlier
  # alternative to `serialize` with respect to dirty attributes.
  module HasSyncedData
    class SyncedData < Hashie::Mash; end

    # Serialize and set remote data from `object`.
    def synced_data=(object)
      write_attribute :synced_data, dump(object)
    ensure
      @synced_data = nil
    end

    # Return remote data as a cached instance.
    def synced_data
      @synced_data ||= SyncedData.new loaded_synced_data
    end

    private

    def loaded_synced_data
      load read_attribute(:synced_data)
    rescue
      {}
    end

    def dump(object)
      JSON.dump object
    end

    def load(source)
      JSON.load source
    end
  end
end
