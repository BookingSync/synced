class BookingAlias < ActiveRecord::Base
  synced only_updated: true,
    endpoint: :bookings
  belongs_to :account

  def self.api
    BookingSync::API::Client.new(ENV["ACCESS_TOKEN"])
  end
end
