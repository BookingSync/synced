class Amenity < ActiveRecord::Base
  class TimestampStrategy < Synced::Strategies::SyncedAllAtTimestampStrategy
    private

    def synced_all_at_key
      :remote_updated_at
    end
  end

  synced id_key: :remote_id, strategy: :updated_since, timestamp_strategy: TimestampStrategy,
    data_key: :remote_data, local_attributes: :name, only_updated: true
  validates :name, exclusion: { in: %w(invalid) }
end
