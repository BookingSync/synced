class RemoveSyncedAllAtFromLocationsAndRentals < ActiveRecord::Migration
  def change
    remove_column :rentals, :synced_all_at, :timestamp
    remove_column :locations, :synced_all_at, :timestamp
  end
end
