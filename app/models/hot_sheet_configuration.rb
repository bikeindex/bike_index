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

  def send_at_today
    Time.current.beginning_of_day + send_seconds_past_midnight
  end

  def create_today_now?
    return false if disabled?
    return false if hot_sheets.where("created_at > ?", Time.current.beginning_of_day).email_success.any?
    Time.current > send_at_today
  end

  def send_hour; send_seconds_past_midnight/3600 end

  def send_hour=(val)
    hour = val.to_i
    if hour > 0 && hour < 24
      self.send_seconds_past_midnight = hour * 3600
    else
      errors(:base, "Invalid time - must be between 0 and 24")
    end
  end

  def set_default_attributes
    unless search_radius_miles.present? && search_radius_miles > 0
      self.search_radius_miles = (organization&.search_radius || 50)
    end
    self.send_seconds_past_midnight ||= 21600 # 6am
  end

  def ensure_location_if_enabled
    return true unless enabled?
    return true if search_coordinates.reject(&:blank?).count == 2
    errors.add(:base, "Organization must have a location set to enable Hot Sheets")
  end
end
