class RemoveSyncedFieldsFromPhotos < ActiveRecord::Migration
  def change
    remove_column :photos, :synced_data, :text
    remove_column :photos, :synced_updated_at, :datetime
  end
end
