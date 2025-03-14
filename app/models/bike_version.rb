# == Schema Information
#
# Table name: bike_versions
#
#  id                        :bigint           not null, primary key
#  belt_drive                :boolean
#  cached_data               :text
#  coaster_brake             :boolean
#  cycle_type                :integer
#  deleted_at                :datetime
#  description               :text
#  end_at                    :datetime
#  extra_registration_number :string
#  frame_material            :integer
#  frame_model               :text
#  frame_size                :string
#  frame_size_number         :float
#  frame_size_unit           :string
#  front_tire_narrow         :boolean
#  handlebar_type            :integer
#  listing_order             :integer
#  manufacturer_other        :string
#  mnfg_name                 :string
#  name                      :string
#  number_of_seats           :integer
#  propulsion_type           :integer
#  rear_tire_narrow          :boolean
#  start_at                  :datetime
#  status                    :integer          default("status_with_owner")
#  thumb_path                :text
#  video_embed               :text
#  visibility                :integer          default("visible_not_related")
#  year                      :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  bike_id                   :bigint
#  front_gear_type_id        :bigint
#  front_wheel_size_id       :bigint
#  manufacturer_id           :bigint
#  owner_id                  :bigint
#  paint_id                  :bigint
#  primary_frame_color_id    :bigint
#  rear_gear_type_id         :bigint
#  rear_wheel_size_id        :bigint
#  secondary_frame_color_id  :bigint
#  tertiary_frame_color_id   :bigint
#
# Indexes
#
#  index_bike_versions_on_bike_id                   (bike_id)
#  index_bike_versions_on_front_gear_type_id        (front_gear_type_id)
#  index_bike_versions_on_front_wheel_size_id       (front_wheel_size_id)
#  index_bike_versions_on_manufacturer_id           (manufacturer_id)
#  index_bike_versions_on_owner_id                  (owner_id)
#  index_bike_versions_on_paint_id                  (paint_id)
#  index_bike_versions_on_primary_frame_color_id    (primary_frame_color_id)
#  index_bike_versions_on_rear_gear_type_id         (rear_gear_type_id)
#  index_bike_versions_on_rear_wheel_size_id        (rear_wheel_size_id)
#  index_bike_versions_on_secondary_frame_color_id  (secondary_frame_color_id)
#  index_bike_versions_on_tertiary_frame_color_id   (tertiary_frame_color_id)
#
class BikeVersion < ApplicationRecord
  include BikeSearchable
  include BikeAttributable
  include PgSearch::Model

  acts_as_paranoid without_default_scope: true

  VISIBILITY_ENUM = {
    visible_not_related: 0,
    all_visible: 1,
    user_hidden: 2
  }.freeze

  belongs_to :bike

  belongs_to :paint # Not in BikeAttributable because of counter cache

  belongs_to :owner, class_name: "User" # Direct association, unlike bike

  enum :visibility, VISIBILITY_ENUM
  enum :status, Bike::STATUS_ENUM # Only included to match bike, always should be with_owner

  attr_accessor :timezone
  attr_writer :end_at_shown, :start_at_shown

  scope :user_hidden, -> { unscoped.user_hidden }

  default_scope { where.not(visibility: "user_hidden").where(deleted_at: nil).order(listing_order: :desc) }

  validates :name, presence: true, uniqueness: {scope: [:bike_id, :owner_id]}

  before_validation :set_calculated_attributes

  delegate :bike_versions,
    :no_serial?, :serial_number, :serial_unknown, :made_without_serial?,
    to: :bike, allow_nil: true

  pg_search_scope :pg_search, against: {
    cached_data: "B",
    description: "C"
  }

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

  # Necessary to duplicate bike
  def status_found?
    false
  end

  # Necessary to duplicate bike
  def pos?
    false
  end

  # Necessary to duplicate bike
  def user
    owner
  end

  # Necessary to duplicate bike
  def user?
    owner.present?
  end

  # Necessary to duplicate bike
  def authorized_by_organization?(*)
    false
  end

  # Necessary to duplicate bike
  def bike_owner_different?
    bike.user_id != owner_id
  end

  # Necessary to duplicate bike
  def bike_stickers
    BikeSticker.none
  end

  # Necessary to duplicate bike
  def organizations
    Organization.none
  end

  # Necessary to duplicate bike
  def stock_photo_url
    nil
  end

  def current_impound_record
    nil
  end

  def current_stolen_record
    nil
  end

  def end_at_shown
    end_at.present?
  end

  def start_at_shown
    start_at.present?
  end

  # Prevent returning ip address, rather than the TLD URL
  def html_url
    "#{ENV["BASE_URL"]}/bike_versions/#{id}"
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
    self.thumb_path = public_images&.limit(1)&.first&.image_url(:small)
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
