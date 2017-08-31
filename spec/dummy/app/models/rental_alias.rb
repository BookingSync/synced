class RentalAlias < ActiveRecord::Base
  synced delegate_attributes: [:total, :zip], strategy: :full, auto_paginate: false,
    handle_processed_objects_proc: Proc.new { |processed_objects|
      processed_objects.each do |rental|
        rental.name = "#{rental.synced_data.name}_modified"
        rental.save
      end
    },
    model_name: "Rental"
  belongs_to :account
  has_many :periods
  has_many :los_records

  validates :synced_id, presence: true

  def import_periods_since
    Time.zone.parse('2009-04-19 14:44:32')
  end

  def api
    @api ||= BookingSync::API.new("ACCESS_TOKEN")
  end
end
