class CreateDestinations < ActiveRecord::Migration
  def change
    create_table :destinations do |t|
      t.string :name
      t.references :location
      t.integer :synced_id

      t.timestamps
    end
  end
end
