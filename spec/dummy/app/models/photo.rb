class Photo < ActiveRecord::Base
  synced data_key: nil, synced_all_at_key: nil, local_attributes: :filename
  belongs_to :location

  def self.cancel_all
    all.each(&:cancel)
  end

  def cancel
    update_attribute(:canceled_at, Time.now)
  end
end
