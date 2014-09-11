class CreatePeriods < ActiveRecord::Migration
  def change
    create_table :periods do |t|
      t.string :start_date
      t.string :end_date
      t.integer :rental_id
      t.integer :synced_id

      t.timestamps
    end
  end
end
