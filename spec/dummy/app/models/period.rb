class Period < ActiveRecord::Base
  synced local_attributes: %w(start_date end_date),
    initial_sync_since: -> (scope) { scope.import_periods_since }

  belongs_to :rental

  scope :published, -> { where("end_date > ?", Time.now.utc) }

  default_scope { published }
end
