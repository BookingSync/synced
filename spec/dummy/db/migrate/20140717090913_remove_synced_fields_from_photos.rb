class RemoveSyncedFieldsFromPhotos < ActiveRecord::Migration
  def change
    remove_column :photos, :synced_data, :text
    remove_column :photos, :synced_all_at, :datetime
  end
end
