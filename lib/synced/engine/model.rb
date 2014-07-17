require "synced/engine/synchronizer"

module Synced::Engine::Model
  # Enables synced for ActiveRecord model.
  #
  # @param options [Hash] Configuration options for synced. They are inherited
  #   by subclasses, but can be overwritten in the subclass.
  # @option options [Symbol] id_key: attribute name under which
  #   remote object's ID is stored, default is :synced_id.
  # @option options [Symbol] updated_at_key: attribute name under which
  #   remote object's updated_at is stored, default is :synced_updated_at.
  # @option options [Symbol] data_key: attribute name under which remote
  #   object's data is stored.
  # @option options [Array] local_attributes: Array of attributes in the remote
  #   object which will be mapped to local object attributes.
  def synced(options = {})
    class_attribute :synced_id_key, :synced_updated_at_key, :synced_data_key,
      :synced_local_attributes, :synced_associations
    self.synced_id_key           = options.fetch(:id_key, :synced_id)
    self.synced_updated_at_key   = options.fetch(:updated_at_key,
      :synced_updated_at)
    self.synced_data_key         = options.fetch(:data_key, :synced_data)
    self.synced_local_attributes = options.fetch(:local_attributes, [])
    self.synced_associations     = options.fetch(:associations, [])
    include Synced::Engine::HasSyncedData
  end

  # Performs synchronization of given remote objects to local database.
  #
  # @param remote [Array] - Remote objects to be synchronized with local db. If
  #   it's nil then synchronizer will make request on it's own.
  # @param model_class [Class] - ActiveRecord model class to which remote objects
  #   will be synchronized.
  # @param scope [ActiveRecord::Base] - Within this object scope local objects
  #   will be synchronized. By default it's model_class.
  # @param delete_if_missing [Boolean] - If it's true all local objects within
  #   current scope which are not present in the remote array will be destroyed.
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
  def synchronize(remote: nil, model_class: self, scope: nil,
                  delete_if_missing: false)
    options = {
      scope: scope,
      id_key: synced_id_key,
      updated_at_key: synced_updated_at_key,
      data_key: synced_data_key,
      delete_if_missing: delete_if_missing,
      local_attributes: synced_local_attributes,
      associations: synced_associations
    }
    synchronizer = Synced::Engine::Synchronizer.new(remote, model_class,
      options)
    synchronizer.perform
  end
end
