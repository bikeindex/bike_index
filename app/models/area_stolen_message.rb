class AreaStolenMessage < ApplicationRecord
  MAX_MESSAGE_LENGTH = 300

  belongs_to :organization
  has_many :stolen_records

  before_validation :set_calculated_attributes

  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }

  def self.for_coordinates(latitude, longitude)
    # Geocoder::Calculations.bounding_box([to_coordinates], search_radius_miles)
  end

  def self.clean_message(str)
    return nil if str.blank?
    ActionController::Base.helpers.strip_tags(str).gsub("&amp;", "&")
      .strip.gsub(/\s+/, " ").truncate(MAX_MESSAGE_LENGTH, omission: "")
  end

  def disabled?
    !enabled?
  end

  def set_calculated_attributes
    self.message = self.class.clean_message(message)
    self.latitude = organization&.location_latitude
    self.longitude = organization&.location_longitude
    self.radius_miles ||= organization.search_radius_miles
    self.enabled = false unless message.present? && latitude.present? &&
      longitude.present? && radius_miles.present?
  end
end
