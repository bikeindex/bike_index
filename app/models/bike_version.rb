class BikeVersion < ApplicationRecord
  include BikeSearchable
  include BikeAttributable

  VISIBILITY_ENUM = {
    all_visible: 0,
    user_hidden: 1,
    visible_not_related: 2
  }.freeze

  belongs_to :bike

  belongs_to :paint # Not in BikeAttributable because of counter cache

  belongs_to :owner, class_name: "User" # Direct association, unlike bike

  enum visibility: VISIBILITY_ENUM

  scope :user_hidden, -> { unscoped.user_hidden }

  default_scope { where.not(visibility: "user_hidden").order(listing_order: :desc) }

  before_validation :set_calculated_attributes

  def authorized?(passed_user, no_superuser_override: false)
    return false if passed_user.blank?
    return true if !no_superuser_override && passed_user.superuser?
    passed_user == owner
  end

  def visible_by?(passed_user = nil)
    return true unless user_hidden?
    if passed_user.present?
      return true if passed_user.superuser?
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
    self.thumb_path = public_images&.first&.image_url(:small)
    self.cached_data = cached_data_array.join(" ")
  end

  # Method from bike that is static in bike_version
  def default_edit_template
    "bike_details"
  end

  # Method from bike that is static in bike_version
  def extra_registration_number
    nil
  end
end
