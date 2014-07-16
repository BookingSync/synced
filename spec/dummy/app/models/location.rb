class Location < ActiveRecord::Base
  synced associations: :photos
  has_many :photos
end
