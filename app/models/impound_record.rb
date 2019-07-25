class ImpoundRecord < ActiveRecord::Base
  belongs_to :bike
  belongs_to :user
  belongs_to :organization

  validates_presence_of :bike_id, :user_id
  validate :only_impounded_once_per_bike
  validate :user_authorized_to_impound

  scope :current, -> { where(retrieved_at: nil) }
  scope :retrieved, -> { where.not(retrieved_at: nil) }

  def current?; retrieved_at.blank? end

  def retrieved?; !current? end

  def only_impounded_once_per_bike
    return true if retrieved?
  end

  def user_authorized_to_impound
    return true if id.present?
  end

  def retrieve!
    update_attributes(retrieved_at: Time.now) if current?
  end
end
