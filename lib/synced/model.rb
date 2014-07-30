require "synced/synchronizer"

module Synced
  module Model
    # Enables synced for ActiveRecord model.
    #
    # @param options [Hash] Configuration options for synced. They are inherited
    #   by subclasses, but can be overwritten in the subclass.
    # @option options [Symbol] id_key: attribute name under which
    #   remote object's ID is stored, default is :synced_id.
    # @option options [Symbol] synced_all_at_key: attribute name under which
    #   last synchronization time is stored, default is :synced_all_at. It's only
    #   used when only_updated option is enabled.
    # @option options [Boolean] only_updated: If true requests to API will take
    #   advantage of updated_since param and fetch only created/changed/deleted
    #   remote objects
    # @option options [Symbol] data_key: attribute name under which remote
    #   object's data is stored.
    # @option options [Array] local_attributes: Array of attributes in the remote
    #   object which will be mapped to local object attributes.
    def synced(options = {})
      class_attribute :synced_id_key, :synced_all_at_key, :synced_data_key,
        :synced_local_attributes, :synced_associations, :synced_only_updated
      self.synced_id_key           = options.fetch(:id_key, :synced_id)
      self.synced_all_at_key       = options.fetch(:synced_all_at_key,
        :synced_all_at)
      self.synced_data_key         = options.fetch(:data_key, :synced_data)
      self.synced_local_attributes = options.fetch(:local_attributes, [])
      self.synced_associations     = options.fetch(:associations, [])
      self.synced_only_updated     = options.fetch(:only_updated, false)
      include Synced::HasSyncedData
    end

    # Performs synchronization of given remote objects to local database.
    #
    # @param remote [Array] - Remote objects to be synchronized with local db. If
    #   it's nil then synchronizer will make request on it's own.
    # @param model_class [Class] - ActiveRecord model class to which remote objects
    #   will be synchronized.
    # @param scope [ActiveRecord::Base] - Within this object scope local objects
    #   will be synchronized. By default it's model_class.
    # @param remove [Boolean] - If it's true all local objects within
    #   current scope which are not present in the remote array will be destroyed.
    #   If only_updated is enabled, ids of objects to be deleted will be taken
    #   from the meta part. By default if cancel_at column is present, all
    #   missing local objects will be canceled with cancel_all,
    #   if it's missing, all will be destroyed with destroy_all.
    #   You can also force method to remove local objects by passing it
    #   to remove: :mark_as_missing.
    # @param api [BookingSync::API::Client] - API client to be used for fetching
    #   remote objects
    # @example Synchronizing amenities
    #
    #   Amenity.synchronize(remote: [remote_amenity1, remote_amenity2])
    #
    # @example Synchronizing rentals within given website. This will
    #   create/remove/update rentals only within website.
    #   It requires relation website.rentals to exist.
    #
    #  Rental.synchronize(remote: remote_rentals, scope: website)
    #
    def synchronize(remote: nil, model_class: self, scope: nil, remove: false,
      include: nil, api: nil)
      options = {
        scope: scope,
        id_key: synced_id_key,
        synced_all_at_key: synced_all_at_key,
        data_key: synced_data_key,
        remove: remove,
        local_attributes: synced_local_attributes,
        associations: synced_associations,
        only_updated: synced_only_updated,
        include: include,
        api: api
      }
      synchronizer = Synced::Synchronizer.new(remote, model_class, options)
      synchronizer.perform
    end
  end
end
