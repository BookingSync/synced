# Synchronizer class which performs actual synchronization between
# local database and given array of remote objects
class Synced::Engine::Synchronizer
  attr_reader :id_key

  # Initializes a new Synchronizer
  #
  # @param remote_objects [Array] Array of objects to be synchronized with
  #   local database. Objects need to respond to at least :id and :updated_at
  #   messages.
  # @param model_class [Class] ActiveRecord model class from which local objects
  #   will be created.
  # @param options [Hash]
  # @option options [Symbol] scope: Within this object scope local objects
  #   will be synchronized. By default it's model_class.
  # @option options [Symbol] id_key: attribute name under which
  #   remote object's ID is stored, default is :synced_id.
  # @option options [Symbol] updated_at_key: attribute name under which
  #   remote object's updated_at is stored, default is :synced_updated_at
  # @option options [Symbol] data_key: attribute name under which remote
  #   object's data is stored.
  # @option options [Array] local_attributes: Array of attributes in the remote
  #   object which will be mapped to local object attributes.
  # @option options [Boolean] delete_if_missing: All local objects which are
  #   missing in the remote Array will be destroyed in the local db. This
  #   option is passed to association synchronizer.
  def initialize(remote_objects, model_class, options = {})
    @remote_objects    = remote_objects
    @model_class       = model_class
    @scope             = options[:scope]
    @id_key            = options[:id_key]
    @updated_at_key    = options[:updated_at_key]
    @data_key          = options[:data_key]
    @delete_if_missing = options[:delete_if_missing]
    @local_attributes  = Array(options[:local_attributes])
    @associations      = Array(options[:associations])
  end

  def perform
    scope.transaction do
      if @delete_if_missing
        scope.where.not(id_key => remote_objects_ids).destroy_all
      end

      @remote_objects.map do |remote|
        local_object = local_object_by_remote_id(remote.id) || scope.new
        local_object.attributes = default_attributes_mapping(remote)
        local_object.attributes = local_attributes_mapping(remote)
        local_object.save! if local_object.changed?
        local_object.tap do |local_object|
          @associations.each do |association|
            klass = association.to_s.classify.constantize
            klass.synchronize(remote: remote[association], scope: local_object,
              delete_if_missing: @delete_if_missing)
          end
        end
      end
    end
  end

  private

  def local_attributes_mapping(remote)
    Hash[@local_attributes.map { |k| [k, remote[k]] }]
  end

  def default_attributes_mapping(remote)
    {}.tap do |attributes|
      attributes[@id_key] = remote.id
      attributes[@data_key] = remote if @data_key
      attributes[@updated_at_key] = remote.updated_at if @updated_at_key
    end
  end

  def scope
    if @scope
      @scope.send(@model_class.to_s.tableize)
    else
      @model_class
    end
  end

  def local_object_by_remote_id(remote_id)
    local_objects.find { |l| l.attributes[id_key.to_s] == remote_id }
  end

  def local_objects
    @local_objects ||= scope.where(id_key => remote_objects_ids).to_a
  end

  def remote_objects_ids
    @remote_objects_ids ||= @remote_objects.map(&:id)
  end
end
