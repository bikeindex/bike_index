class HotSheetConfiguration < ApplicationRecord
  belongs_to :organization

  has_many :hot_sheets, through: :organization

  validates_presence_of :organization_id, :send_seconds_past_midnight, :search_radius_miles
  validate :ensure_location_if_on

  before_validation :set_calculated_attributes

  delegate :search_coordinates, to: :organization, allow_nil: true

  scope :on, -> { where(is_on: true) }

  def on?
    is_on
  end

  def off?
    !on?
  end

  def current_recipients
    organization.users.where(id: current_recipient_ids)
  end

  def current_recipient_ids
    organization.memberships.claimed.notification_daily.pluck(:user_id)
  end

  def bounding_box
    Geocoder::Calculations.bounding_box(search_coordinates, search_radius_miles)
  end

  def timezone
    TimeParser.parse_timezone(timezone_str)
  end

  def time_in_zone
    Time.current.in_time_zone(timezone)
  end

  def search_radius_metric_units?
    organization&.metric_units?
  end

  def send_today_at
    time_in_zone.beginning_of_day + send_seconds_past_midnight
  end

  def send_hour
    send_seconds_past_midnight / 3600
  end

  def send_today_now?
    return false if off?
    return false if hot_sheets.where(sheet_date: time_in_zone.to_date).email_success.any?
    time_in_zone > send_today_at
  end

  def send_hour=(val)
    hour = val.to_f
    hour = 0 unless hour >= 0 && hour < 24
    self.send_seconds_past_midnight = hour * 3600
  end

  def search_radius_kilometers
    (search_radius_miles.to_d / "1.609344".to_d).to_i
  end

  def search_radius_kilometers=(val)
    self.search_radius_miles = val.to_d * "1.609344".to_d
  end

  def set_calculated_attributes
    unless search_radius_miles.present? && search_radius_miles > 1
      self.search_radius_miles = organization&.search_radius || 50
      # switch km default to 100
      self.search_radius_kilometers = 100 if search_radius_metric_units? && search_radius_miles == 50
    end
    # Store a parsed value - needs to store name, because timeparser can't parse timezone.to_s
    self.timezone_str = TimeParser.parse_timezone(timezone_str)&.name
    self.send_seconds_past_midnight ||= 21_600 # 6am
  end

  def ensure_location_if_on
    return true unless on?
    return true if search_coordinates.reject(&:blank?).count == 2
    self.is_on = false
    errors.add(:base, "Organization must have a location set to enable Hot Sheets")
  end
end
