class Rental < ActiveRecord::Base
  include Synced::HasSyncedData
end
