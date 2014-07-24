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
    # @option options [Boolean] only_updated: If true requests to API will take
    #   advantage of updated_since param and fetch only created/changed/deleted
    #   remote objects
    def initialize(remote_objects, model_class, options = {})
      @model_class       = model_class
      @scope             = options[:scope]
      @id_key            = options[:id_key]
      @synced_all_at_key = options[:synced_all_at_key]
      @data_key          = options[:data_key]
      @remove            = options[:remove]
      @only_updated      = options[:only_updated]
      @include           = options[:include]
      @local_attributes  = options[:local_attributes]
      @associations      = Array(options[:associations])
      @remote_objects    = Array(remote_objects) if remote_objects
      @request_performed = false
    end

    def perform
      relation_scope.transaction do
        remove_relation.send(remove_strategy) if @remove

        remote_objects.map do |remote|
          local_object = local_object_by_remote_id(remote.id) || relation_scope.new
          local_object.attributes = default_attributes_mapping(remote)
          local_object.attributes = local_attributes_mapping(remote)
          local_object.save! if local_object.changed?
          local_object.tap do |local_object|
            @associations.each do |association|
              klass = association.to_s.classify.constantize
              klass.synchronize(remote: remote[association], scope: local_object,
                remove: @remove)
            end
          end
        end.tap do |local_objects|
          if updated_since_enabled? && @request_performed
            relation_scope.update_all(@synced_all_at_key => Time.now)
          end
        end
      end
    end

    private

    def local_attributes_mapping(remote)
      if @local_attributes.is_a?(Hash)
        Hash[@local_attributes.map { |k, v| [k, remote[v]] }]
      else
        Hash[Array(@local_attributes).map { |k| [k, remote[k]] }]
      end
    end

    def default_attributes_mapping(remote)
      {}.tap do |attributes|
        attributes[@id_key] = remote.id
        attributes[@data_key] = remote if @data_key
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
      @scope ? @scope.send(resource_name) : @model_class
    end

    # Returns api client from the closest possible source.
    #
    # @raise [BookingSync::API::Unauthorized] - On unauthorized user
    # @return [BookingSync::API::Client] BookingSync API client
    def api
      closest = [@scope, @scope.class, @model_class].detect do |o|
                  o.respond_to?(:api)
                end
      closest && closest.api || raise(MissingAPIClient.new(@scope, @model_class))
    end

    def local_object_by_remote_id(remote_id)
      local_objects.find { |l| l.attributes[id_key.to_s] == remote_id }
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
      api.paginate(resource_name, api_request_options).tap do
        @request_performed = true
      end
    end

    def api_request_options
      {}.tap do |options|
        options[:include] = @associations if @associations.present?
        if @include.present?
          options[:include] ||= []
          options[:include] += @include
        end
        options[:updated_since] = minimum_updated_at if updated_since_enabled?
        options[:auto_paginate] = true
      end
    end

    def minimum_updated_at
      relation_scope.minimum(@synced_all_at_key)
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
      if @only_updated
        relation_scope.where(id_key => deleted_remote_objects_ids)
      else
        relation_scope.where.not(id_key => remote_objects_ids)
      end
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
