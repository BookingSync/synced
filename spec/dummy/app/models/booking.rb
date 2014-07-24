class Booking < ActiveRecord::Base
  synced only_updated: true, local_attributes: {name: :short_name}
  belongs_to :account
end
