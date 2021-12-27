class BikeVersion < ApplicationRecord
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

  scope :user_hidden, -> { unscoped.where(user_hidden: true) }

  default_scope { without_deleted.where(user_hidden: false).order(listing_order: :desc) }

  before_validation :set_calculated_attributes

  def calculated_listing_order
    t = (updated_at || Time.current).to_i / 10000
    public_images.present? ? t : t / 100
  end

  def set_calculated_attributes
    self.listing_order = calculated_listing_order
  end
end
