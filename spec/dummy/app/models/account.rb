class Account < ActiveRecord::Base
  has_many :rentals

  def api
    @api ||= BookingSync::API.new("ACCESS_TOKEN")
  end
end
