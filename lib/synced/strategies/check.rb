module Synced
  module Strategies
    # This strategy doesn't do any synchronization it simply verifies if local objects are in sync
    # with the remote ones (taken from the API).
    class Check < Full
      attr_reader :result

      def initialize(model_class, options = {})
        super
        @result = Result.new(model_class, options)
      end

      # Makes a DRY run of full synchronization. It checks and collects objects which
      #   * are present in the local database, but not in the API. Local AR object is
      #      returned - additional objects
      #   * are present in the API, but not in the local database, remote object is
      #      returned - missing objects
      #   * are changed in the API, but not in the local database,
      #      ActiveRecord::Model #changes hash is returned - changed objects
      # @return [Synced::Strategies::Check::Result] Integrity check result
      def perform
        process_remote_objects(remote_objects_tester)
        result.additional = remove_relation.to_a
        result
      end

      def remote_objects_tester
        lambda do |remote_objects|
          @remote_objects_ids.concat(remote_objects.map(&:id))
          local_objects = relation_scope.where(@id_key => remote_objects.map(&:id))
          local_objects_hash = local_objects.each_with_object({}) do |local_object, hash|
            hash[local_object.public_send(@id_key)] = local_object
          end

          remote_objects.map do |remote|
            if local_object = local_objects_hash[remote.id]
              remote.extend(@mapper) if @mapper
              local_object.attributes = default_attributes_mapping(remote)
              local_object.attributes = local_attributes_mapping(remote)
              if @globalized_attributes.present?
                local_object.attributes = globalized_attributes_mapping(remote,
                  local_object.translations.translated_locales)
              end
              if local_object.changed?
                result.changed << [{ id: local_object.id }, local_object.changes]
              end
            else
              result.missing << remote
            end
          end
        end
      end

      # If we check model which uses cancel instead of destroy, we skip canceled
      # when searching for additional objects by searching in :visible scope
      def relation_scope
        default_remove_strategy == :cancel_all ? super.visible : super
      end

      # Represents result of synchronization integrity check
      class Result
        attr_accessor :model_class, :options, :changed, :missing, :additional

        def initialize(model_class = nil, options = {})
          @model_class = model_class
          @options = options
          @changed, @missing, @additional = [], [], []
        end

        def passed?
          changed.empty? && missing.empty? && additional.empty?
        end
      end
    end
  end
end
