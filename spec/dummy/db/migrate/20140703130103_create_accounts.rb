class CreateAccounts < ActiveRecord::Migration
  def change
    create_table :accounts do |t|
      t.string :name

      t.timestamps
    end
    add_column :rentals, :account_id, :integer
  end
end
