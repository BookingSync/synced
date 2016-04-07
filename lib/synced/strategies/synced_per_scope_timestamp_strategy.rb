require 'synced/timestamp'

module Synced
  module Strategies
    # This is a strategy for UpdatedSince defining how to store and update synced timestamps.
    # It uses a separate timestamps table to track when different models were synced in specific scopes.
    class SyncedPerScopeTimestampStrategy
      attr_reader :scope, :model_class
      private     :scope, :model_class

      def initialize(scope: nil, model_class:, **_options)
        @scope = scope
        @model_class = model_class
      end

      def last_synced_at
        timestamp_repository.last_synced_at
      end

      def update(timestamp)
        timestamp_repository.create!(synced_at: timestamp)
      end

      def reset
        timestamp_repository.delete_all
      end

      private

      def timestamp_repository
        @timestamp_repository ||= begin
          if scope
            Synced::Timestamp.with_scope_and_model(scope, model_class)
          else
            Synced::Timestamp.with_model(model_class)
          end
        end
      end
    end
  end
end
