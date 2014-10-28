class AddSyncedAllAtToPeriods < ActiveRecord::Migration
  def change
    add_column :periods, :synced_all_at, :timestamp
  end
end
