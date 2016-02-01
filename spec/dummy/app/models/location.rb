class Location < ActiveRecord::Base
  synced associations: [:photos, :destination], remove: true, include: :addresses,
    globalized_attributes: :name, strategy: :full

  has_many :photos
  has_many :destinations
  has_one :destination
  translates :name

  def self.api
    BookingSync::API::Client.new("CREDENTIALS_FLOW_ACCESS_TOKEN")
  end
end
