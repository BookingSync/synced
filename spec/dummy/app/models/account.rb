class Account < ActiveRecord::Base
  has_many :rentals
  has_many :bookings
  has_many :los_records
  has_many :booking_aliases

  def import_bookings_since
    Time.zone.parse("2015-01-01 12:00:00")
  end

  def api
    @api ||= BookingSync::API.new(ENV["ACCESS_TOKEN"])
  end
end
