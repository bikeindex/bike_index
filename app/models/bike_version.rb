class BikeVersion < ApplicationRecord
  VISIBILITY_ENUM = {
    all_visible: 0,
    user_hidden: 1,
    visible_not_related: 2
  }.freeze

  acts_as_paranoid without_default_scope: true

  belongs_to :bike

  belongs_to :manufacturer
  belongs_to :primary_frame_color, class_name: "Color"
  belongs_to :secondary_frame_color, class_name: "Color"
  belongs_to :tertiary_frame_color, class_name: "Color"
  belongs_to :rear_wheel_size, class_name: "WheelSize"
  belongs_to :front_wheel_size, class_name: "WheelSize"
  belongs_to :rear_gear_type
  belongs_to :front_gear_type
  belongs_to :paint

  belongs_to :owner, class_name: "User" # Direct association, unlike bike
  has_many :public_images, as: :imageable, dependent: :destroy
  has_many :components

  enum visibility: VISIBILITY_ENUM

  scope :user_hidden, -> { unscoped.user_hidden }

  default_scope { without_deleted.where.not(visibility: "user_hidden").order(listing_order: :desc) }

  before_validation :set_calculated_attributes

  def authorized?(u, no_superuser_override: false)
    return false if u.blank?
    return true if !no_superuser_override && u.superuser?
    u == owner
  end

  def visible_by?(passed_user = nil)
    return true unless user_hidden? || deleted?
    if passed_user.present?
      return true if passed_user.superuser?
      return false if deleted?
      return true if user_hidden? && authorized?(passed_user)
    end
    false
  end

  def calculated_listing_order
    t = (updated_at || Time.current).to_i / 10000
    public_images.present? ? t : t / 100
  end

  def set_calculated_attributes
    self.listing_order = calculated_listing_order
  end
end
