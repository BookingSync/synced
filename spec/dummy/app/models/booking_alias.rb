class BookingAlias < ActiveRecord::Base
  synced only_updated: true,
    mapper: -> { EmptyOne },
    endpoint: :bookings
  belongs_to :account

  def self.api
    BookingSync::API::Client.new(ENV["ACCESS_TOKEN"])
  end

  module EmptyOne
  end
end
