class CreateBookingAliases < ActiveRecord::Migration
  def change
    create_table :booking_aliases do |t|
      t.integer :account_id
      t.datetime :synced_all_at
      t.integer :synced_id
      t.text :synced_data

      t.timestamps
    end
  end
end
