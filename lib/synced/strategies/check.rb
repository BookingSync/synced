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
        result.additional = remove_relation.to_a
        remote_objects.map do |remote|
          if local_object = local_object_by_remote_id(remote.id)
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
        result
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
