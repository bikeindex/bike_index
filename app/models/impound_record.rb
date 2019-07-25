class ImpoundRecord < ActiveRecord::Base
  belongs_to :bike
  belongs_to :user
  belongs_to :organization

  validates_presence_of :bike_id, :user_id
  validates_uniqueness_of :bike_id, if: :current?, conditions: -> { current }
  validate :user_authorized, on: :create

  scope :current, -> { where(retrieved_at: nil) }
  scope :retrieved, -> { where.not(retrieved_at: nil) }

  def current?; retrieved_at.blank? end

  def retrieved?; !current? end

  def user_authorized
    return true if id.present?
  end

  def mark_retrieved
    update_attributes(retrieved_at: Time.now) if current?
  end
end
