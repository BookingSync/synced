class Location < ActiveRecord::Base
  synced associations: :photos, remove: true, include: :addresses,
    globalized_attributes: :name

  has_many :photos
  translates :name

  def self.api
    BookingSync::API::Client.new("CREDENTIALS_FLOW_ACCESS_TOKEN")
  end
end
