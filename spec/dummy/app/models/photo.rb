class Photo < ActiveRecord::Base
  synced local_attributes: :filename
  belongs_to :location

  def self.cancel_all
    all.each(&:cancel)
  end

  def cancel
    update_attribute(:canceled_at, Time.now)
  end

  scope :visible, -> { where(canceled_at: nil) }
end
