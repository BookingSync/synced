require 'synced/delegate_attributes'
require 'synced/attributes_as_hash'
require 'synced/strategies/full'
require 'synced/strategies/check'
require 'synced/strategies/updated_since'

# Synchronizer class which performs actual synchronization between
# local database and given array of remote objects
module Synced
  class Synchronizer
    attr_reader :strategy

    # Initializes a new Synchronizer
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
    # @option options [Symbol] strategy: Strategy to be used for synchronization
    #   process, possible values are :full, :updated_since, :check.
    def initialize(model_class, strategy:, **options)
      @model_class       = model_class
      @only_updated      = options[:only_updated]
      @remote            = options[:remote]
      @strategy          = strategy_class(strategy).new(model_class, options)
    end

    def perform
      @strategy.perform
    end

    def reset_synced
      @strategy.reset_synced
    end

    private

    def strategy_class(name)
      name = :full if force_full_strategy?
      "Synced::Strategies::#{name.to_s.classify}".constantize
    end

    def force_full_strategy?
      @remote
    end
  end
end
