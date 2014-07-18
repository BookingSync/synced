class Account < ActiveRecord::Base
  has_many :rentals
  has_many :bookings

  def api
    @api ||= BookingSync::API.new("ACCESS_TOKEN")
  end
end
