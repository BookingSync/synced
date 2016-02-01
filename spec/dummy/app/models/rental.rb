class Rental < ActiveRecord::Base
  synced delegate_attributes: [:total, :zip], strategy: :full
  belongs_to :account
  has_many :periods
  has_many :los_records

  def import_periods_since
    Time.parse('2009-04-19 14:44:32')
  end

  def api
    @api ||= BookingSync::API.new("ACCESS_TOKEN")
  end
end
