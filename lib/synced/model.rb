require "synced/synchronizer"

module Synced
  module Model
    # Enables synced for ActiveRecord model.
    #
    # @param options [Hash] Configuration options for synced. They are inherited
    #   by subclasses, but can be overwritten in the subclass.
    # @option options [Symbol] strategy: synchronization strategy, one of :full, :updated_since, :check.
    #   Defaults to :updated_since
    # @option options [Symbol] id_key: attribute name under which
    #   remote object's ID is stored, default is :synced_id.
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
    # @option options [Array|Hash] delegate_attributes: Given attributes will be defined
    #   on synchronized object and delegated to synced_data Hash
    # @option options [Hash] query_params: Given attributes and their values
    #   which will be passed to api client to perform search
    # @option options [Boolean] auto_paginate: If true (default) will fetch and save all
    #   records at once. If false will fetch and save records in batches.
    # @option options transaction_per_page [Boolean]: If false (default) all fetched records
    #   will be persisted within single transaction. If true the transaction will be per page
    #   of fetched records
    # @option options [Proc] handle_processed_objects_proc: Proc taking one argument (persisted remote objects).
    #   Called after persisting remote objects (once in case of auto_paginate, after each batch
    #   when paginating with block).
    def synced(strategy: :updated_since, **options)
      options.assert_valid_keys(:associations, :data_key, :fields,
        :globalized_attributes, :id_key, :include, :initial_sync_since,
        :local_attributes, :mapper, :only_updated, :remove, :auto_paginate, :transaction_per_page,
        :delegate_attributes, :query_params, :timestamp_strategy, :handle_processed_objects_proc, :endpoint)
      class_attribute :synced_id_key, :synced_data_key,
        :synced_local_attributes, :synced_associations, :synced_only_updated,
        :synced_mapper, :synced_remove, :synced_include, :synced_fields, :synced_auto_paginate, :synced_transaction_per_page,
        :synced_globalized_attributes, :synced_initial_sync_since, :synced_delegate_attributes,
        :synced_query_params, :synced_timestamp_strategy, :synced_strategy, :synced_handle_processed_objects_proc, :synced_endpoint
      self.synced_strategy              = strategy
      self.synced_id_key                = options.fetch(:id_key, :synced_id)
      self.synced_data_key              = options.fetch(:data_key,
        synced_column_presence(:synced_data))
      self.synced_local_attributes      = options.fetch(:local_attributes, [])
      self.synced_associations          = options.fetch(:associations, [])
      self.synced_only_updated          = options.fetch(:only_updated, synced_strategy == :updated_since)
      self.synced_mapper                = options.fetch(:mapper, nil)
      self.synced_remove                = options.fetch(:remove, false)
      self.synced_include               = options.fetch(:include, [])
      self.synced_fields                = options.fetch(:fields, [])
      self.synced_globalized_attributes = options.fetch(:globalized_attributes,
        [])
      self.synced_initial_sync_since    = options.fetch(:initial_sync_since,
        nil)
      self.synced_delegate_attributes   = options.fetch(:delegate_attributes, [])
      self.synced_query_params          = options.fetch(:query_params, {})
      self.synced_timestamp_strategy    = options.fetch(:timestamp_strategy, nil)
      self.synced_auto_paginate         = options.fetch(:auto_paginate, true)
      self.synced_transaction_per_page  = options.fetch(:transaction_per_page, false)
      self.synced_handle_processed_objects_proc  = options.fetch(:handle_processed_objects_proc, nil)
      self.synced_endpoint              = options.fetch(:endpoint, self.table_name)
      include Synced::DelegateAttributes
      include Synced::HasSyncedData
    end

    # Performs synchronization of given remote objects to local database.
    #
    # @param remote [Array] - Remote objects to be synchronized with local db. If
    #   it's nil then synchronizer will make request on it's own.
    # @param model_class [Class] - ActiveRecord model class to which remote objects
    #   will be synchronized.
    # @param scope [ActiveRecord::Base] - Within this object scope local objects
    #   will be synchronized. By default it's model_class. Can be infered from active record association scope.
    # @param remove [Boolean] - If it's true all local objects within
    #   current scope which are not present in the remote array will be destroyed.
    #   If only_updated is enabled, ids of objects to be deleted will be taken
    #   from the meta part. By default if cancel_at column is present, all
    #   missing local objects will be canceled with cancel_all,
    #   if it's missing, all will be destroyed with destroy_all.
    #   You can also force method to remove local objects by passing it
    #   to remove: :mark_as_missing. This option can be defined in the model
    #   and then overwritten in the synchronize method.
    # @param auto_paginate [Boolean] - If true (default) will fetch and save all
    #   records at once. If false will fetch and save records in batches.
    # @param transaction_per_page [Boolean] - If false (default) all fetched records
    #   will be persisted within single transaction. If true the transaction will be per page
    #   of fetched records
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
    #  website.rentals.synchronize(remote: remote_rentals)
    #
    def synchronize(scope: scope_from_relation, strategy: synced_strategy, **options)
      options.assert_valid_keys(:api, :fields, :include, :remote, :remove, :query_params, :association_sync, :auto_paginate, :transaction_per_page)
      options[:remove]  = synced_remove unless options.has_key?(:remove)
      options[:include] = Array.wrap(synced_include) unless options.has_key?(:include)
      options[:fields]  = Array.wrap(synced_fields) unless options.has_key?(:fields)
      options[:query_params] = synced_query_params unless options.has_key?(:query_params)
      options[:auto_paginate] = synced_auto_paginate unless options.has_key?(:auto_paginate)
      options[:transaction_per_page] = synced_transaction_per_page unless options.has_key?(:transaction_per_page)
      options.merge!({
        scope:                 scope,
        strategy:              strategy,
        id_key:                synced_id_key,
        synced_data_key:       synced_data_key,
        data_key:              synced_data_key,
        local_attributes:      synced_local_attributes,
        associations:          synced_associations,
        only_updated:          synced_only_updated,
        mapper:                synced_mapper,
        globalized_attributes: synced_globalized_attributes,
        initial_sync_since:    synced_initial_sync_since,
        timestamp_strategy:    synced_timestamp_strategy,
        handle_processed_objects_proc:  synced_handle_processed_objects_proc,
        synced_endpoint:       synced_endpoint
      })
      Synced::Synchronizer.new(self, options).perform
    end

    # Reset last sync timestamp for given scope, this forces synced to sync
    # all the records on the next sync. Useful for cases when you add
    # a new column to be synced and you use updated since strategy for faster
    # synchronization.
    def reset_synced(scope: scope_from_relation)
      options = {
        scope:                 scope,
        strategy:              synced_strategy,
        only_updated:          synced_only_updated,
        initial_sync_since:    synced_initial_sync_since,
        timestamp_strategy:    synced_timestamp_strategy,
        synced_endpoint:       synced_endpoint
      }
      Synced::Synchronizer.new(self, options).reset_synced
    end

    private

    # attempt to get scope from association reflection, so you could do:
    # account.bookings.synchronize
    # and the scope would be account
    def scope_from_relation
      all.proxy_association.owner if all.respond_to?(:proxy_association)
    end

    def synced_column_presence(name)
      name if column_names.include?(name.to_s)
    end
  end
end
