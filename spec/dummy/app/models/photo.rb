class Photo < ActiveRecord::Base
  synced data_key: nil, updated_at_key: nil, local_attributes: :filename
  belongs_to :location
end
