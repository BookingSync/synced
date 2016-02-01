class Destination < ActiveRecord::Base
  synced delegate_attributes: [:name], strategy: :full

  belongs_to :location
end
