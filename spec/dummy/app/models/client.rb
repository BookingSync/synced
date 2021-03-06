class Client < ActiveRecord::Base
  module SyncedMapper
    def first_name
      name.split(' ').first
    end

    def last_name
      name.split(' ').last
    end
  end

  synced mapper: SyncedMapper, local_attributes: %w(first_name last_name),
    include: :addresses, fields: [:name], strategy: :full, auto_paginate: false

  def self.api
    BookingSync::API::Client.new("CREDENTIALS_FLOW_ACCESS_TOKEN")
  end
end
