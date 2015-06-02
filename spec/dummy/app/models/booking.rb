class Booking < ActiveRecord::Base
  synced only_updated: true, local_attributes: { name: :short_name,
    reviews_count: -> (booking) { booking.reviews.size if booking.respond_to?(:reviews) } },
    mapper: -> { EmptyOne },
    search_params: { from: -> scope { scope.import_bookings_since } }
  belongs_to :account

  module EmptyOne
  end
end
