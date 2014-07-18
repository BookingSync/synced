class CreateBookings < ActiveRecord::Migration
  def change
    create_table :bookings do |t|
      t.string :name
      t.datetime :synced_all_at
      t.integer :synced_id
      t.text :synced_data
      t.integer :account_id

      t.timestamps
    end
  end
end
