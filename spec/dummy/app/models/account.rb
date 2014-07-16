class Account < ActiveRecord::Base
  has_many :rentals
end
