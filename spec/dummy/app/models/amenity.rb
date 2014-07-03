class Amenity < ActiveRecord::Base
  synced id_key: :remote_id, updated_at_key: :remote_updated_at,
    data_key: :remote_data, local_attributes: :name
  validates :name, exclusion: { in: %w(invalid) }
end
