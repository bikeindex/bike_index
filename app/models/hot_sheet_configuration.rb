# == Schema Information
#
# Table name: hot_sheet_configurations
#
#  id                         :bigint           not null, primary key
#  is_on                      :boolean          default(FALSE)
#  search_radius_miles        :float
#  send_seconds_past_midnight :integer
#  timezone_str               :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  organization_id            :bigint
#
# Indexes
#
#  index_hot_sheet_configurations_on_organization_id  (organization_id)
#
class HotSheetConfiguration < ApplicationRecord
  include SearchRadiusMetricable

  MISSING_LOCATION_ERROR = "Organization must have a location set to enable Hot Sheets".freeze

  belongs_to :organization

  has_many :hot_sheets, through: :organization

  validates_presence_of :organization_id, :send_seconds_past_midnight, :search_radius_miles
  validate :ensure_location_if_on

  before_validation :set_calculated_attributes

  delegate :search_coordinates, :metric_units?, to: :organization, allow_nil: true

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

  def timezone
    TimeZoneParser.parse(timezone_str)
  end

  def time_in_zone
    Time.current.in_time_zone(timezone)
  end

  def send_today_at
    time_in_zone.beginning_of_day + send_seconds_past_midnight
  end

  def send_hour
    send_seconds_past_midnight / 3600
  end

  def current_date
    time_in_zone.to_date
  end

  def send_today_now?
    return false if off? ||
      hot_sheets.where(sheet_date: current_date).email_success.any?
    time_in_zone > send_today_at
  end

  def send_hour=(val)
    hour = val.to_f
    hour = 0 unless hour >= 0 && hour < 24
    self.send_seconds_past_midnight = hour * 3600
  end

  def set_calculated_attributes
    # Store a parsed value - needs to store name, because timeparser can't parse timezone.to_s
    self.timezone_str = TimeZoneParser.parse(timezone_str)&.name
    self.send_seconds_past_midnight ||= 21_600 # 6am
  end

  def ensure_location_if_on
    return true unless on?
    return true if search_coordinates.count(&:present?) == 2
    self.is_on = false
    errors.add(:base, MISSING_LOCATION_ERROR)
  end
end
