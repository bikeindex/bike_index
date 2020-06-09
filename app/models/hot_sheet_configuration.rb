class HotSheetConfiguration < ApplicationRecord
  belongs_to :organization

  validates_presence_of :organization_id, :send_seconds_past_midnight, :search_radius_miles

  before_validation :set_default_attributes

  delegate :search_coordinates, to: :organization, allow_nil: true

  scope :enabled, -> { where(enabled: true) }

  def bounding_box; Geocoder::Calculations.bounding_box(search_coordinates, search_radius_miles) end

  def set_default_attributes
    self.search_radius_miles ||= organization&.search_radius
    self.send_seconds_past_midnight ||= 360
    # Need to enable setting these more comfortably: :send_seconds_past_midnight :timezone_str
  end
end
