class CreateRentalAlias < ActiveRecord::Migration
  def change
    create_table :rental_aliases do |t|
      t.string :name
      t.integer :synced_id
      t.text :synced_data
      t.datetime :synced_all_at

      t.timestamps
    end
    add_index :rental_aliases, :synced_id
  end
end
