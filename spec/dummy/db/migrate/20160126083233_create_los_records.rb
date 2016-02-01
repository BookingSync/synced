class CreateLosRecords < ActiveRecord::Migration
  def change
    create_table :los_records do |t|
      t.belongs_to :account, index: true
      t.integer :synced_id, index: true
      t.integer :rate
      t.timestamps
    end
  end
end
