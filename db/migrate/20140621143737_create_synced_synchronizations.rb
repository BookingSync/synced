class CreateSyncedSynchronizations < ActiveRecord::Migration
  def change
    create_table :synced_synchronizations do |t|
      t.string :model
      t.datetime :synchronized_at

      t.timestamps
    end
  end
end
