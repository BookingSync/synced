class AddCanceledAtToPhotos < ActiveRecord::Migration
  def change
    add_column :photos, :canceled_at, :datetime
  end
end
