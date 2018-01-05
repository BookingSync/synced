require "synced/strategies/synced_all_at_timestamp_strategy"
require "synced/strategies/synced_per_scope_timestamp_strategy"

module Synced
  module Strategies
    # This strategy performs partial synchronization.
    # It fetches only changes (additions, modifications and deletions) from the API.
    class UpdatedSince < Full
      # @option options [Time|Proc] initial_sync_since: A point in time from which
      #   objects will be synchronized on first synchronization.
      def initialize(model_class, options = {})
        super
        @initial_sync_since = options[:initial_sync_since]
        timestampt_strategy_class = options[:timestamp_strategy] || Synced::Strategies::SyncedAllAtTimestampStrategy
        @timestamp_strategy = timestampt_strategy_class.new(relation_scope: relation_scope, scope: @scope, model_class: model_class)
      end

      def perform
        super.tap do |local_objects|
          instrument("update_synced_timestamp_perform.synced", model: @model_class) do
            @timestamp_strategy.update(first_request_timestamp)
          end
        end
      end

      def reset_synced
        @timestamp_strategy.reset
      end

      private

      def api_request_options
        super.merge(updated_since: updated_since)
      end

      def initial_sync_since
        if @initial_sync_since.respond_to?(:call)
          @initial_sync_since.arity == 0 ? @initial_sync_since.call :
            @initial_sync_since.call(@scope)
        else
          @initial_sync_since
        end
      end

      def updated_since
        instrument("updated_since.synced") do
          last_synced_at_offset = ENV.fetch("LAST_SYNCED_AT_OFFSET", 0).to_i
          [
            @timestamp_strategy.last_synced_at&.advance(seconds: last_synced_at_offset),
            initial_sync_since
          ].compact.max
        end
      end

      def deleted_remote_objects_ids
        meta && meta[:deleted_ids] or raise CannotDeleteDueToNoDeletedIdsError.new(@model_class)
      end

      def first_request_timestamp
        if first_response_headers && first_response_headers["x-updated-since-request-synced-at"]
          Time.zone.parse(first_response_headers["x-updated-since-request-synced-at"])
        end
      end

      def meta
        @meta ||=
          (api.last_response && api.last_response.meta) || {}
      end

      def first_response_headers
        @first_response_headers ||=
          (api.pagination_first_response && api.pagination_first_response.headers) || {}
      end

      # Remove all objects with ids from deleted_ids field in the meta key
      def remove_relation
        relation_scope.where(@id_key => deleted_remote_objects_ids)
      end

      def additional_errors_check
        raise MissingTimestampError.new unless first_request_timestamp
      end

      class CannotDeleteDueToNoDeletedIdsError < StandardError
        def initialize(model_class)
          @model_class = model_class
        end

        def message
          "Cannot delete #{pluralized_model_class}. No deleted_ids were returned in API response."
        end

        private

        def pluralized_model_class
          @model_class.to_s.pluralize
        end
      end

      class MissingTimestampError < StandardError
        def message
          "Synchronization failed. API response is missing 'x-updated-since-request-synced-at' header."
        end
      end
    end
  end
end
