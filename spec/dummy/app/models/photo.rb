class Photo < ActiveRecord::Base
  synced
  belongs_to :location
end
