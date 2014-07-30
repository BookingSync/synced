class AddReviewsCountToBookings < ActiveRecord::Migration
  def change
    add_column :bookings, :reviews_count, :integer
  end
end
