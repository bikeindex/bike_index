class ImpoundRecord < ApplicationRecord
  belongs_to :bike
  belongs_to :user
  belongs_to :organization

  has_many :parking_notifications

  validates_presence_of :bike_id, :user_id
  validates_uniqueness_of :bike_id, if: :current?, conditions: -> { current }
  validate :user_authorized, on: :create

  after_commit :update_associations

  scope :current, -> { where(retrieved_at: nil) }
  scope :retrieved, -> { where.not(retrieved_at: nil) }

  def current?; retrieved_at.blank? end

  def retrieved?; !current? end

  def user_authorized
    return true if id.present? # Already authorized, doesn't matter if still is
    return true if user.present? && user.can_impound? && organization.present? &&
                   user.authorized?(organization) && organization.enabled?("impound_bikes")
    errors.add(:user_id, :user_not_authorized)
  end

  def mark_retrieved
    update_attributes(retrieved_at: Time.current) if current?
  end

  def update_associations
    bike.update_attributes(updated_at: Time.current)
  end
end
