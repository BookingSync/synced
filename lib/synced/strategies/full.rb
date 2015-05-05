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
      # @option options [Symbol] synced_all_at_key: attribute name under which
      #   remote object's sync time is stored, default is :synced_all_at
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
      def initialize(model_class, options = {})
        @model_class           = model_class
        @scope                 = options[:scope]
        @id_key                = options[:id_key]
        @synced_all_at_key     = options[:synced_all_at_key]
        @data_key              = options[:data_key]
        @remove                = options[:remove]
        @only_updated          = options[:only_updated]
        @include               = options[:include]
        @local_attributes      = synced_attributes_as_hash(options[:local_attributes])
        @api                   = options[:api]
        @mapper                = options[:mapper].respond_to?(:call) ?
                                   options[:mapper].call : options[:mapper]
        @fields                = options[:fields]
        @remove                = options[:remove]
        @associations          = Array(options[:associations])
        @perform_request       = options[:remote].nil?
        @remote_objects        = Array(options[:remote]) unless @perform_request
        @globalized_attributes = synced_attributes_as_hash(options[:globalized_attributes])
      end

      def perform
        instrument("perform.synced", model: @model_class) do
          relation_scope.transaction do
            instrument("remove_perform.synced", model: @model_class) do
              remove_relation.send(remove_strategy) if @remove
            end
            instrument("sync_perform.synced", model: @model_class) do
              remote_objects.map do |remote|
                remote.extend(@mapper) if @mapper
                local_object = local_object_by_remote_id(remote.id) || relation_scope.new
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
            end
          end
        end
      end

      private

      def synchronize_associations(remote, local_object)
        @associations.each do |association|
          klass = association.to_s.classify.constantize
          klass.synchronize(remote: remote[association], scope: local_object, remove: @remove)
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
        closest.try(:api) || raise(MissingAPIClient.new(@scope, @model_class))
      end

      def local_object_by_remote_id(remote_id)
        local_objects.find { |l| l.public_send(@id_key) == remote_id }
      end

      def local_objects
        @local_objects ||= relation_scope.where(@id_key => remote_objects_ids).to_a
      end

      def remote_objects_ids
        @remote_objects_ids ||= remote_objects.map(&:id)
      end

      def remote_objects
        @remote_objects ||= @perform_request ? fetch_remote_objects : nil
      end

      def fetch_remote_objects
        instrument("fetch_remote_objects.synced", model: @model_class) do
          api.paginate(resource_name, api_request_options)
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
          options[:auto_paginate] = true
        end
      end

      def resource_name
        @model_class.to_s.tableize
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
