class Photo < ActiveRecord::Base
  synced data_key: nil, updated_at_key: nil
  belongs_to :location
end
