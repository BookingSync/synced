module Synced
  module Strategies
    # This is a strategy for UpdatedSince defining how to store and update synced timestamps.
    # It uses synced_all_at column on model to store update time.
    class SyncedAllAtTimestampStrategy
      attr_reader :relation_scope

      def initialize(relation_scope:, **_options)
        @relation_scope = relation_scope
      end

      def last_synced_at
        relation_scope.minimum(synced_all_at_key)
      end

      def update(timestamp)
        relation_scope.update_all(synced_all_at_key => timestamp)
      end

      def reset
        relation_scope.update_all(synced_all_at_key => nil)
      end

      private

      def synced_all_at_key
        :synced_all_at
      end
    end
  end
end
