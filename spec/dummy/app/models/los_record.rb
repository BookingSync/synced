class LosRecord < ActiveRecord::Base
  synced strategy: :updated_since, timestamp_strategy: Synced::Strategies::SyncedPerScopeTimestampStrategy
  belongs_to :account
end
