class CreateAmenities < ActiveRecord::Migration
  def change
    create_table :amenities do |t|
      t.string :name
      t.integer :remote_id
      t.datetime :remote_updated_at
      t.text :remote_data

      t.timestamps
    end
  end
end
