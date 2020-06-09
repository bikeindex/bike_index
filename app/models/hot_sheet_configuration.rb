class HotSheetConfiguration < ApplicationRecord
  belongs_to :organization

  validates_presence_of :organization_id, :send_seconds_past_midnight, :search_radius_miles
  validate :ensure_location_if_enabled

  before_validation :set_default_attributes

  delegate :search_coordinates, to: :organization, allow_nil: true

  scope :enabled, -> { where(enabled: true) }

  def bounding_box; Geocoder::Calculations.bounding_box(search_coordinates, search_radius_miles) end

  def set_default_attributes
    unless search_radius_miles.present? && search_radius_miles > 0
      self.search_radius_miles = (organization&.search_radius || 50)
    end
    self.send_seconds_past_midnight ||= 360
    # Need to enable setting these more comfortably: :send_seconds_past_midnight :timezone_str
  end

  def ensure_location_if_enabled
    return true unless enabled
    return true if search_coordinates.reject(&:blank?).count == 2
    errors.add(:base, "Organization must have a location set to enable Hot Sheets")
  end
end
