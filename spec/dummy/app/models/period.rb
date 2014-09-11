class Period < ActiveRecord::Base
  synced local_attributes: %w(start_date end_date)

  belongs_to :rental

  scope :published, -> { where("end_date > ?", Time.now.utc) }

  default_scope { published }
end
