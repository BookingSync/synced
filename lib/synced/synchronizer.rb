# Synchronizer class which performs actual synchronization between
# local database and given array of remote objects
module Synced
  class Synchronizer
    attr_reader :id_key

    # Initializes a new Synchronizer
    #
    # @param remote_objects [Array|NilClass] Array of objects to be synchronized
    #   with local database. Objects need to respond to at least :id message.
    #   If it's nil, then synchronizer will fetch the remote objects on it's own.
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
      @local_attributes      = attributes_as_hash(options[:local_attributes])
      @api                   = options[:api]
      @mapper                = options[:mapper].respond_to?(:call) ?
                               options[:mapper].call : options[:mapper]
      @fields                = options[:fields]
      @remove                = options[:remove]
      @associations          = Array(options[:associations])
      @remote_objects        = Array(options[:remote]) unless options[:remote].nil?
      @request_performed     = false
      @globalized_attributes = attributes_as_hash(options[:globalized_attributes])
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
                @associations.each do |association|
                  klass = association.to_s.classify.constantize
                  klass.synchronize(remote: remote[association], scope: local_object,
                    remove: @remove)
                end
              end
            end
          end.tap do |local_objects|
            if updated_since_enabled? && @request_performed
              instrument("update_synced_all_at_perform.synced", model: @model_class) do
                relation_scope.update_all(@synced_all_at_key => Time.now)
              end
            end
          end
        end
      end
    end

    private

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
      closest = [@scope, @scope.class, @model_class].detect do |o|
                  o.respond_to?(:api)
                end
      closest && closest.api || raise(MissingAPIClient.new(@scope, @model_class))
    end

    def local_object_by_remote_id(remote_id)
      local_objects.find { |l| l.public_send(id_key) == remote_id }
    end

    def local_objects
      @local_objects ||= relation_scope.where(id_key => remote_objects_ids).to_a
    end

    def remote_objects_ids
      @remote_objects_ids ||= remote_objects.map(&:id)
    end

    def remote_objects
      @remote_objects ||= fetch_remote_objects
    end

    def deleted_remote_objects_ids
      remote_objects unless @request_performed
      api.last_response.meta[:deleted_ids]
    end

    def fetch_remote_objects
      instrument("fetch_remote_objects.synced", model: @model_class) do
        api.paginate(resource_name, api_request_options).tap do
          @request_performed = true
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
        options[:updated_since] = minimum_updated_at if updated_since_enabled?
        options[:auto_paginate] = true
      end
    end

    def minimum_updated_at
      instrument("minimum_updated_at.synced") do
        relation_scope.minimum(@synced_all_at_key)
      end
    end

    def updated_since_enabled?
      @only_updated && @synced_all_at_key
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

    def remove_relation
      if @only_updated && @request_performed
        relation_scope.where(id_key => deleted_remote_objects_ids)
      else
        relation_scope.where.not(id_key => remote_objects_ids)
      end
    end

    def instrument(*args, &block)
      Synced.instrumenter.instrument(*args, &block)
    end

    def attributes_as_hash(attributes)
      return attributes if attributes.is_a?(Hash)
      Hash[Array(attributes).map { |name| [name, name] }]
    end

    class MissingAPIClient < StandardError
      def initialize(scope, model_class)
        @scope = scope
        @model_class = model_class
      end

      def message
        if @scope
          %Q{Missing BookingSync API client in #{@scope} object or
  #{@scope.class} class}
        else
          %Q{Missing BookingSync API client in #{@model_class} class}
        end
      end
    end
  end
end
