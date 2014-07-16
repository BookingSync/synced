class Rental < ActiveRecord::Base
  synced
  belongs_to :account
end
