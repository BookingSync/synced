class AddSyncedFieldsToRentals < ActiveRecord::Migration
  def change
    add_column :rentals, :synced_id, :integer
    add_index :rentals, :synced_id
    add_column :rentals, :synced_data, :text
    add_column :rentals, :synced_all_at, :datetime
  end
end
