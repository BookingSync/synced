class Booking < ActiveRecord::Base
  synced only_updated: true
  belongs_to :account
end
