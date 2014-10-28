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
    # @option options [Array|Hash] local_attributes: Array of attributes in the remote
    #   object which will be mapped to local object attributes.
    # @option options [Boolean|Symbol] remove: If it's true all local objects
    #   within current scope which are not present in the remote array will be
    #   destroyed.
    #   If only_updated is enabled, ids of objects to be deleted will be taken
    #   from the meta part. By default if cancel_at column is present, all
    #   missing local objects will be canceled with cancel_all,
    #   if it's missing, all will be destroyed with destroy_all.
    #   You can also force method to remove local objects by passing it
    #   to remove: :mark_as_missing.
    # @option options [Array|Hash] globalized_attributes: A list of attributes
    #   which will be mapped with their translations.
    # @option options [Time|Proc] initial_sync_since: A point in time from which
    #   objects will be synchronized on first synchronization.
    #   Works only for partial (updated_since param) synchronizations.
    def synced(options = {})
      options.symbolize_keys!
      options.assert_valid_keys(:associations, :data_key, :fields,
        :globalized_attributes, :id_key, :include, :initial_sync_since,
        :local_attributes, :mapper, :only_updated, :remove, :synced_all_at_key)
      class_attribute :synced_id_key, :synced_all_at_key, :synced_data_key,
        :synced_local_attributes, :synced_associations, :synced_only_updated,
        :synced_mapper, :synced_remove, :synced_include, :synced_fields,
        :synced_globalized_attributes, :synced_initial_sync_since
      self.synced_id_key                = options.fetch(:id_key, :synced_id)
      self.synced_all_at_key            = options.fetch(:synced_all_at_key,
        synced_column_presence(:synced_all_at))
      self.synced_data_key              = options.fetch(:data_key,
        synced_column_presence(:synced_data))
      self.synced_local_attributes      = options.fetch(:local_attributes, [])
      self.synced_associations          = options.fetch(:associations, [])
      self.synced_only_updated          = options.fetch(:only_updated,
        column_names.include?(synced_all_at_key.to_s))
      self.synced_mapper                = options.fetch(:mapper, nil)
      self.synced_remove                = options.fetch(:remove, false)
      self.synced_include               = options.fetch(:include, [])
      self.synced_fields                = options.fetch(:fields, [])
      self.synced_globalized_attributes = options.fetch(:globalized_attributes,
        [])
      self.synced_initial_sync_since    = options.fetch(:initial_sync_since,
        nil)
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
    #   to remove: :mark_as_missing. This option can be defined in the model
    #   and then overwritten in the synchronize method.
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
    def synchronize(options = {})
      options.symbolize_keys!
      options.assert_valid_keys(:api, :fields, :include, :remote, :remove,
        :scope)
      options[:remove]  = synced_remove unless options.has_key?(:remove)
      options[:include] = Array(synced_include) unless options.has_key?(:include)
      options[:fields]  = Array(synced_fields) unless options.has_key?(:fields)
      options.merge!({
        id_key:                synced_id_key,
        synced_data_key:       synced_data_key,
        synced_all_at_key:     synced_all_at_key,
        data_key:              synced_data_key,
        local_attributes:      synced_local_attributes,
        associations:          synced_associations,
        only_updated:          synced_only_updated,
        mapper:                synced_mapper,
        globalized_attributes: synced_globalized_attributes,
        initial_sync_since:    synced_initial_sync_since
      })
      Synced::Synchronizer.new(self, options).perform
    end

    # Reset synced_all_at for given scope, this forces synced to sync
    # all the records on the next sync. Useful for cases when you add
    # a new column to be synced and you use updated since strategy for faster
    # synchronization.
    def reset_synced
      return unless synced_only_updated
      update_all(synced_all_at_key => nil)
    end

    private

    def synced_column_presence(name)
      name if column_names.include?(name.to_s)
    end
  end
end
