# == Schema Information
#
# Table name: locations
# Database name: primary
#
#  id                       :integer          not null, primary key
#  default_impound_location :boolean          default(FALSE)
#  deleted_at               :datetime
#  email                    :string(255)
#  impound_location         :boolean          default(FALSE)
#  latitude                 :float
#  longitude                :float
#  name                     :string(255)
#  not_publicly_visible     :boolean          default(FALSE)
#  phone                    :string(255)
#  shown                    :boolean          default(FALSE)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  address_record_id        :bigint
#  organization_id          :integer
#
# Indexes
#
#  index_locations_on_address_record_id  (address_record_id)
#
class Location < ApplicationRecord
  include AddressRecorded

  acts_as_paranoid

  belongs_to :organization, inverse_of: :locations # Locations are organization locations

  has_many :bikes
  has_many :impound_records

  validates :name, presence: true
  validate :organization_present

  scope :shown, -> { where(shown: true) }
  scope :publicly_visible, -> { shown.where(not_publicly_visible: false) }
  scope :impound_locations, -> { where(impound_location: true) }
  scope :default_impound_locations, -> { impound_locations.where(default_impound_location: true) }
  # scope :international, where("country_id IS NOT #{Country.united_states_id}")

  before_validation :set_calculated_attributes
  after_commit :update_associations
  before_destroy :ensure_destroy_permitted!

  attr_accessor :skip_update

  # For now, doesn't do anything - but eventually we may switch to slugged locations, so prep for it
  def self.friendly_find(str)
    find_by_id(str)
  end

  def other_organization_locations
    Location.where(organization_id: organization_id).where.not(id: id)
  end

  # Override AddressRecorded delegation to fall back to legacy fields
  def address_present?
    return address_record.address_present? if address_record?

    [street, city, zipcode].any?(&:present?)
  end

  def find_or_build_address_record(current_country_id: nil)
    return address_record if address_record?

    current_country_id ||= Country.united_states_id
    d_address_record = AddressRecord.where(organization_id:).order(:id).first
    return AddressRecord.new(country_id: current_country_id) if d_address_record.blank?

    AddressRecord.new(country_id: d_address_record.country_id || current_country_id,
      region_record_id: d_address_record.region_record_id,
      region_string: d_address_record.region_string)
  end

  def org_location_id
    "#{organization_id}_#{id}"
  end

  def publicly_visible
    !not_publicly_visible
  end

  # may block if it has impound records
  def destroy_forbidden?
    default_impound_location? || impound_records.any?
  end

  def publicly_visible=(val)
    self.not_publicly_visible = !Binxtils::InputNormalizer.boolean(val)
  end

  def set_calculated_attributes
    if name.blank? && organization.present? && organization.locations.count == 0
      self.name = organization.name
    end
    self.phone = Phonifyer.phonify(phone)
    self.shown = calculated_shown
    self.latitude = address_record&.latitude
    self.longitude = address_record&.longitude
    if address_record.present?
      address_record.organization_id = organization_id
      address_record.kind = :organization
    end
  end

  def update_associations
    return true if skip_update

    # If this wasn't set by the organization callback (which uses skip_update: true)
    # And this location was updated with default_impound_location, ensure there aren't any others
    if default_impound_location
      # Updating columns, no need to skip_update
      other_organization_locations.update_all(default_impound_location: false)
    end
    # Because we need to update the organization and make sure it is shown on
    # the map correctly, manually update to ensure that it runs save callbacks
    organization&.reload&.update(updated_at: Time.current)
  end

  def display_name
    return "" if organization.blank?

    (name == organization.name) ? name : "#{organization.name} - #{name}"
  end

  # Quick and dirty hack to ensure it's blocked - frontend should prevent doing this normally
  def ensure_destroy_permitted!
    return true unless destroy_forbidden?

    raise StandardError, "Can't destroy a location with impounded bikes"
  end

  private

  def organization_present
    return if organization.present? || organization_id.present?

    errors.add(:organization, :blank)
  end

  def calculated_shown
    return false if not_publicly_visible

    organization.present? && organization.allowed_show?
  end
end
