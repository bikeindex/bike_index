class StravaIntegration < ApplicationRecord
  STATUSES = %w[pending syncing synced error].freeze

  belongs_to :user
  has_many :strava_activities, dependent: :destroy
  has_many :strava_gear_associations, dependent: :destroy

  validates :access_token, presence: true
  validates :refresh_token, presence: true
  validates :status, inclusion: {in: STATUSES}

  scope :syncing, -> { where(status: "syncing") }

  def syncing?
    status == "syncing"
  end

  def synced?
    status == "synced"
  end

  def error?
    status == "error"
  end

  def sync_progress_percent
    return 0 if athlete_activity_count.blank? || athlete_activity_count.zero?
    [(activities_downloaded_count.to_f / athlete_activity_count * 100).round, 100].min
  end

  def gear_names
    return [] if athlete_gear.blank?
    athlete_gear.map { |g| g["name"] }.compact
  end

  def cycling_gear_ids
    return [] if athlete_gear.blank?
    athlete_gear.select { |g| g["primary"] == true || g["resource_state"].present? }
      .map { |g| g["id"] }.compact
  end
end
