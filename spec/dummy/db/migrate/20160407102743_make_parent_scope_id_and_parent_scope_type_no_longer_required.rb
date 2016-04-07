class MakeParentScopeIdAndParentScopeTypeNoLongerRequired < ActiveRecord::Migration
  def change
    change_column :synced_timestamps, :parent_scope_id,   :integer, null: true
    change_column :synced_timestamps, :parent_scope_type, :string,  null: true
  end
end
