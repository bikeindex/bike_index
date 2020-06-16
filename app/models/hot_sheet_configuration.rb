class HotSheetConfiguration < ApplicationRecord
  belongs_to :organization

  has_many :hot_sheets, through: :organization

  validates_presence_of :organization_id, :send_seconds_past_midnight, :search_radius_miles
  validate :ensure_location_if_enabled

  before_validation :set_default_attributes

  delegate :search_coordinates, to: :organization, allow_nil: true

  scope :enabled, -> { where(is_enabled: true) }

  def enabled?; is_enabled end

  def disabled?; !enabled? end

  def bounding_box; Geocoder::Calculations.bounding_box(search_coordinates, search_radius_miles) end

  def timezone; TimeParser.parse_timezone(timezone_str) end

  def time_in_zone; Time.current.in_time_zone(timezone) end

  def send_today_at
    time_in_zone.beginning_of_day + send_seconds_past_midnight
  end

  def send_today_now?
    return false if disabled?
    return false if hot_sheets.where(sheet_date: time_in_zone.to_date).email_success.any?
    time_in_zone > send_today_at
  end

  def send_hour; send_seconds_past_midnight/3600 end

  def send_hour=(val)
    hour = val.to_i
    hour = 0 unless hour >= 0 && hour < 24
    self.send_seconds_past_midnight = hour * 3600
  end

  def set_default_attributes
    unless search_radius_miles.present? && search_radius_miles > 0
      self.search_radius_miles = (organization&.search_radius || 50)
    end
    self.send_seconds_past_midnight ||= 0 # midnight
  end

  def ensure_location_if_enabled
    return true unless enabled?
    return true if search_coordinates.reject(&:blank?).count == 2
    errors.add(:base, "Organization must have a location set to enable Hot Sheets")
  end
end
