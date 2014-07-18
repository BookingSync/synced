class Amenity < ActiveRecord::Base
  synced id_key: :remote_id, synced_all_at_key: :remote_updated_at,
    data_key: :remote_data, local_attributes: :name, only_updated: true
  validates :name, exclusion: { in: %w(invalid) }
end
