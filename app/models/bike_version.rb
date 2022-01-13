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
  enum status: Bike::STATUS_ENUM # Only included to match bike, always should be with_owner

  scope :user_hidden, -> { unscoped.user_hidden }

  default_scope { where.not(visibility: "user_hidden").order(listing_order: :desc) }

  validates :name, uniqueness: {scope: [:bike_id, :owner_id]}

  before_validation :set_calculated_attributes

  delegate :bike_versions,
    :no_serial?, :serial_number, :serial_unknown, :made_without_serial?,
    to: :bike, allow_nil: true

  def self.original_bike_override_attributes
    %w[manufacturer manufacturer_other mnfg_name
      frame_model frame_material
      frame_size frame_size_unit frame_size_number]
  end

  def version?
    true
  end

  # Methods that duplicate bike
  def status_found?
    false
  end
  def deleted?
    false
  end
  def user
    owner
  end
  def user?
    owner.present?
  end
  def authorized_by_organization?(u: nil, org: nil)
    false
  end
  def bike_stickers
    BikeSticker.none
  end
  def organizations
    Organization.none
  end

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
    # And the bike attributes
    self.frame_material = bike&.frame_material
    self.manufacturer_id = bike&.manufacturer_id
    self.mnfg_name = bike&.mnfg_name
    self.manufacturer_other = bike&.manufacturer_other
    self.year = bike&.year
    self.frame_size = bike&.frame_size
    self.frame_size_unit = bike&.frame_size_unit
    self.frame_size_number = bike&.frame_size_number
  end

  # Method from bike that is static in bike_version
  def default_edit_template
    "bike_details"
  end
end
