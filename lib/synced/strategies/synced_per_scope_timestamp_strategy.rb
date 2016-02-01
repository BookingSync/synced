require 'synced/timestamp'

module Synced
  module Strategies
    # This is a strategy for UpdatedSince defining how to store and update synced timestamps.
    # It uses a separate timestamps table to track when different models were synced in specific scopes.
    class SyncedPerScopeTimestampStrategy
      def initialize(scope:, model_class:, **_options)
        @scope = scope
        @model_class = model_class
      end

      def last_synced_at
        Synced::Timestamp.with_scope_and_model(@scope, @model_class).last_synced_at
      end

      def update(timestamp)
        Synced::Timestamp.with_scope_and_model(@scope, @model_class).create!(synced_at: timestamp)
      end

      def reset
        Synced::Timestamp.with_scope_and_model(@scope, @model_class).delete_all
      end
    end
  end
end
