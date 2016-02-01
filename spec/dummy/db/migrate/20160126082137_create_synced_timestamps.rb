class CreateSyncedTimestamps < ActiveRecord::Migration
  def change
    create_table :synced_timestamps do |t|
      t.belongs_to :parent_scope, polymorphic: true, null: false
      t.string :model_class, null: false
      t.datetime :synced_at, null: false
    end

    add_index :synced_timestamps, [:parent_scope_id, :parent_scope_type, :synced_at], name: 'synced_timestamps_max_index', order: { synced_at: 'DESC' }
  end
end
