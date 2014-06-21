class CreateRentals < ActiveRecord::Migration
  def change
    create_table :rentals do |t|
      t.string :name

      t.timestamps
    end
  end
end
