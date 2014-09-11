class Rental < ActiveRecord::Base
  synced
  belongs_to :account
  has_many :periods
end
