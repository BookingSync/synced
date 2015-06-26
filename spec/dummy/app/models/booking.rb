class Booking < ActiveRecord::Base
  synced only_updated: true, local_attributes: { name: :short_name,
    reviews_count: -> (booking) { booking.reviews.size if booking.respond_to?(:reviews) } },
    mapper: -> { EmptyOne }
  belongs_to :account

  def self.api
    BookingSync::API::Client.new("CREDENTIALS_FLOW_ACCESS_TOKEN")
  end

  module EmptyOne
  end
end
