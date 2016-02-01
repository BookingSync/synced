class Synced::Timestamp < ActiveRecord::Base
  self.table_name = 'synced_timestamps'
  belongs_to :parent_scope, polymorphic: true
  scope :with_scope_and_model, ->(parent_scope, model_class) { where(parent_scope: parent_scope, model_class: model_class.to_s) }
  validates :parent_scope, :model_class, :synced_at, presence: true
  scope :old, -> { where('synced_at < ?', 1.week.ago) }

  def model_class=(value)
    write_attribute(:model_class, value.to_s)
  end

  def self.last_synced_at
    maximum(:synced_at)
  end

  def self.cleanup
    old.delete_all
  end
end
