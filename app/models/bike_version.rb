class BikeVersion < ApplicationRecord
  include BikeSearchable
  include BikeAttributable
  acts_as_paranoid without_default_scope: true

  VISIBILITY_ENUM = {
    visible_not_related: 0,
    all_visible: 1,
    user_hidden: 2
  }.freeze

  belongs_to :bike

  belongs_to :paint # Not in BikeAttributable because of counter cache

  belongs_to :owner, class_name: "User" # Direct association, unlike bike

  enum visibility: VISIBILITY_ENUM
  enum status: Bike::STATUS_ENUM # Only included to match bike, always should be with_owner

  scope :user_hidden, -> { unscoped.user_hidden }

  default_scope { where.not(visibility: "user_hidden").where(deleted_at: nil).order(listing_order: :desc) }

  validates :name, presence: true, uniqueness: {scope: [:bike_id, :owner_id]}

  before_validation :set_calculated_attributes

  delegate :bike_versions,
    :no_serial?, :serial_number, :serial_unknown, :made_without_serial?,
    to: :bike, allow_nil: true

  def self.bike_override_attributes
    %i[manufacturer_id manufacturer_other mnfg_name frame_model frame_material
       year frame_size frame_size_unit frame_size_number]
  end

  # Get it unscoped, because unregistered_bike notifications
  def bike
    @bike ||= bike_id.present? ? Bike.unscoped.find_by_id(bike_id) : nil
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

  def authorized_by_organization?(*)
    false
  end

  def bike_owner_different?
    bike.user_id != owner_id
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
    # Only update bike_override attributes if the bike is the same owner, to prevent abuse. Maybe change someday?
    unless bike.blank? || bike_owner_different?
      self.attributes = bike_overridden_attributes
    end
    self.listing_order = calculated_listing_order
    self.thumb_path = public_images&.first&.image_url(:small)
    self.cached_data = cached_data_array.join(" ")
    self.name = name.present? ? name.strip : nil
  end

  # Method from bike that is static in bike_version
  def default_edit_template
    "bike_details"
  end

  private

  def bike_overridden_attributes
    self.class.bike_override_attributes.map { |k| [k, bike.send(k)] }
      .reject { |_k, v| v.blank? }.to_h
  end
end
