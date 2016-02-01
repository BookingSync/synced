class Account < ActiveRecord::Base
  has_many :rentals
  has_many :bookings
  has_many :los_records

  def import_bookings_since
    Time.parse("2015-01-01 12:00:00")
  end

  def api
    @api ||= BookingSync::API.new("ACCESS_TOKEN")
  end
end
