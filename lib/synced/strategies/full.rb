module Synced
  module Strategies
    # This strategy performs full synchronization.
    # It takes all the objects from the API and
    #   - creates missing in the local database
    #   - removes local objects which are missing the API
    #   - updates local objects which are changed in the API
    # This is the base synchronization strategy.
    class Full
      include AttributesAsHash

      # Initializes new Full sync strategy
      #
      # @param remote_objects [Array|NilClass] Array of objects to be synchronized
      #   with local database. Objects need to respond to at least :id message.
      #   If it's nil, then synchronizer will fetch the remote objects on it's own from the API.
      # @param model_class [Class] ActiveRecord model class from which local objects
      #   will be created.
      # @param options [Hash]
      # @option options [Symbol] scope: Within this object scope local objects
      #   will be synchronized. By default it's model_class.
      # @option options [Symbol] id_key: attribute name under which
      #   remote object's ID is stored, default is :synced_id.
      # @option options [Symbol] data_key: attribute name under which remote
      #   object's data is stored.
      # @option options [Array] local_attributes: Array of attributes in the remote
      #   object which will be mapped to local object attributes.
      # @option options [Boolean] remove: If it's true all local objects within
      #   current scope which are not present in the remote array will be destroyed.
      #   If only_updated is enabled, ids of objects to be deleted will be taken
      #   from the meta part. By default if cancel_at column is present, all
      #   missing local objects will be canceled with cancel_all,
      #   if it's missing, all will be destroyed with destroy_all.
      #   You can also force method to remove local objects by passing it
      #   to remove: :mark_as_missing.
      # @param api [BookingSync::API::Client] - API client to be used for fetching
      #   remote objects
      # @option options [Boolean] only_updated: If true requests to API will take
      #   advantage of updated_since param and fetch only created/changed/deleted
      #   remote objects
      # @option options [Module] mapper: Module class which will be used for
      #   mapping remote objects attributes into local object attributes
      # @option options [Array|Hash] globalized_attributes: A list of attributes
      #   which will be mapped with their translations.
      # @option options [Boolean] auto_paginate: If true (default) will fetch and save all
      #   records at once. If false will fetch and save records in batches.
      # @options options [Boolean] transaction_per_page: if false (default) all fetched records
      #   will be persisted within single transaction. If true the transaction will be per page
      #   of fetched records
      def initialize(model_class, options = {})
        @model_class           = model_class
        @synced_model_name     = options[:synced_model_name]
        @scope                 = options[:scope]
        @id_key                = options[:id_key]
        @data_key              = options[:data_key]
        @only_updated          = options[:only_updated]
        @include               = options[:include]
        @local_attributes      = synced_attributes_as_hash(options[:local_attributes])
        @api                   = options[:api]
        @mapper                = options[:mapper].respond_to?(:call) ?
                                   options[:mapper].call : options[:mapper]
        @fields                = options[:fields]
        @remove                = options[:remove]
        @associations          = Array.wrap(options[:associations])
        @association_sync      = options[:association_sync]
        @perform_request       = options[:remote].nil? && !@association_sync
        @remote_objects        = Array.wrap(options[:remote]) unless @perform_request
        @globalized_attributes = synced_attributes_as_hash(options[:globalized_attributes])
        @query_params         = options[:query_params]
        @auto_paginate         = options[:auto_paginate]
        @transaction_per_page  = options[:transaction_per_page]
        @handle_processed_objects_proc = options[:handle_processed_objects_proc]
        @remote_objects_ids = []
      end

      def perform
        instrument("perform.synced", model: @model_class) do
          processed_objects = instrument("sync_perform.synced", model: @model_class) do
            process_remote_objects(remote_objects_persistor)
          end
          relation_scope.transaction do
            instrument("remove_perform.synced", model: @model_class) do
              remove_relation.send(remove_strategy) if @remove
            end
          end
          processed_objects
        end
      end

      def reset_synced
        RuntimeError.new("Full strategy does not support reset_synced functionality")
      end

      private

      def remote_objects_persistor
        lambda do |remote_objects_batch|
          additional_errors_check
          remote_objects_batch_ids = remote_objects_batch.map(&:id)
          local_objects = relation_scope.where(@id_key => remote_objects_batch_ids)
          local_objects_hash = local_objects.each_with_object({}) do |local_object, hash|
            hash[local_object.public_send(@id_key)] = local_object
          end
          @remote_objects_ids.concat(remote_objects_batch_ids)

          processed_objects =
            remote_objects_batch.map do |remote|
              remote.extend(@mapper) if @mapper
              local_object = local_objects_hash[remote.id] || relation_scope.new
              local_object.attributes = default_attributes_mapping(remote)
              local_object.attributes = local_attributes_mapping(remote)
              if @globalized_attributes.present?
                local_object.attributes = globalized_attributes_mapping(remote,
                  local_object.translations.translated_locales)
              end
              local_object.save! if local_object.changed?
              local_object.tap do |local_object|
                synchronize_associations(remote, local_object)
              end
            end

          @handle_processed_objects_proc.call(processed_objects) if @handle_processed_objects_proc.respond_to?(:call)
          processed_objects
        end
      end

      def synchronize_associations(remote, local_object)
        @associations.each do |association|
          klass = association.to_s.classify.constantize
          klass.synchronize(remote: remote[association], scope: local_object, remove: @remove,
            association_sync: true)
        end
      end

      def local_attributes_mapping(remote)
        Hash[@local_attributes.map do |k, v|
          [k, v.respond_to?(:call) ? v.call(remote) : remote.send(v)]
        end]
      end

      def default_attributes_mapping(remote)
        {}.tap do |attributes|
          attributes[@id_key] = remote.id
          attributes[@data_key] = remote if @data_key
        end
      end

      def globalized_attributes_mapping(remote, used_locales)
        empty = Hash[used_locales.map { |locale| [locale.to_s, nil] }]
        {}.tap do |attributes|
          @globalized_attributes.each do |local_attr, remote_attr|
            translations = empty.merge(remote.send(remote_attr) || {})
            attributes["#{local_attr}_translations"] = translations
          end
        end
      end

      # Returns relation within which local objects are created/edited and removed
      # If no scope is provided, the relation_scope will be class on which
      # .synchronize method is called.
      # If scope is provided, like: account, then relation_scope will be a relation
      # account.rentals (given we run .synchronize on Rental class)
      #
      # @return [ActiveRecord::Relation|Class]
      def relation_scope
        if @scope
          @model_class.unscoped { @scope.send(resource_name).scope }
        else
          @model_class.unscoped
        end
      end

      # Returns api client from the closest possible source.
      #
      # @raise [BookingSync::API::Unauthorized] - On unauthorized user
      # @return [BookingSync::API::Client] BookingSync API client
      def api
        return @api if @api
        closest = [@scope, @scope.class, @model_class].find do |object|
                    object.respond_to?(:api)
                  end
        @api ||= closest.try(:api) || raise(MissingAPIClient.new(@scope, @model_class))
      end

      def remote_objects_ids
        @remote_objects_ids
      end

      def process_remote_objects(processor)
        if @remote_objects
          processor.call(@remote_objects)
        elsif @perform_request
          fetch_and_save_remote_objects(processor)
        else
          nil
        end
      end

      def fetch_and_save_remote_objects(processor)
        instrument("fetch_remote_objects.synced", model: @model_class) do
          if @transaction_per_page
            api.paginate(resource_name, api_request_options) do |batch|
              relation_scope.transaction do
                processor.call(batch)
              end
            end
          elsif @auto_paginate
            relation_scope.transaction do
              processor.call(api.paginate(resource_name, api_request_options))
            end
          else
            relation_scope.transaction do
              api.paginate(resource_name, api_request_options) do |batch|
                processor.call(batch)
              end
            end
          end
        end
      end

      def api_request_options
        {}.tap do |options|
          options[:include] = @associations if @associations.present?
          if @include.present?
            options[:include] ||= []
            options[:include] += @include
          end
          options[:fields] = @fields if @fields.present?
          options[:auto_paginate] = @auto_paginate
        end.merge(query_params)
      end

      def query_params
        Hash[@query_params.map do |param, value|
          final_value = value.respond_to?(:call) ? search_param_value_for_lambda(value) : value
          [param, final_value]
        end]
      end

      def search_param_value_for_lambda(func)
        func.arity == 0 ? func.call : func.call(@scope)
      end

      def resource_name
        @synced_model_name.tableize
      end

      def remove_strategy
        @remove == true ? default_remove_strategy : @remove
      end

      def default_remove_strategy
        if @model_class.column_names.include?("canceled_at")
          :cancel_all
        else
          :destroy_all
        end
      end

      # Remove all local objects which are not present in the remote objects
      def remove_relation
        relation_scope.where.not(@id_key => remote_objects_ids)
      end

      def instrument(*args, &block)
        Synced.instrumenter.instrument(*args, &block)
      end

      def additional_errors_check
      end

      class MissingAPIClient < StandardError
        def initialize(scope, model_class)
          @scope = scope
          @model_class = model_class
        end

        def message
          if @scope
            %Q{Missing BookingSync API client in #{@scope} object or \
#{@scope.class} class when synchronizing #{@model_class} model}
          else
            %Q{Missing BookingSync API client in #{@model_class} class}
          end
        end
      end
    end
  end
end
