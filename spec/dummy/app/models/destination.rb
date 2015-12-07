class Destination < ActiveRecord::Base
  synced delegate_attributes: [:name]

  belongs_to :location
end
