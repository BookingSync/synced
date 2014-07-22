class CreateLocations < ActiveRecord::Migration
  def change
    create_table :locations do |t|
      t.string :name
      t.integer :synced_id
      t.datetime :synced_all_at
      t.text :synced_data

      t.timestamps
    end
  end
end
