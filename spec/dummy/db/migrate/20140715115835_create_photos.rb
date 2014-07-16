class CreatePhotos < ActiveRecord::Migration
  def change
    create_table :photos do |t|
      t.string :filename
      t.integer :synced_id
      t.datetime :synced_updated_at
      t.text :synced_data
      t.integer :location_id

      t.timestamps
    end
  end
end
