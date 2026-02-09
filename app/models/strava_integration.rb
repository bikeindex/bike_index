# == Schema Information
#
# Table name: strava_integrations
# Database name: primary
#
#  id                          :bigint           not null, primary key
#  access_token                :text             not null
#  activities_downloaded_count :integer          default(0), not null
#  athlete_activity_count      :integer
#  athlete_gear                :jsonb
#  deleted_at                  :datetime
#  refresh_token               :text             not null
#  status                      :integer          default("pending"), not null
#  token_expires_at            :datetime
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  athlete_id                  :string
#  user_id                     :bigint           not null
#
# Indexes
#
#  index_strava_integrations_on_deleted_at  (deleted_at)
#  index_strava_integrations_on_user_id     (user_id) UNIQUE WHERE (deleted_at IS NULL)
#
class StravaIntegration < ApplicationRecord
  STATUS_ENUM = {pending: 0, syncing: 1, synced: 2, error: 3, disconnected: 4}.freeze

  acts_as_paranoid

  belongs_to :user
  has_many :strava_activities, dependent: :destroy
  has_many :strava_gear_associations, dependent: :destroy

  enum :status, STATUS_ENUM

  validates :access_token, presence: true
  validates :refresh_token, presence: true

  before_destroy :mark_disconnected

  def sync_progress_percent
    return 0 if athlete_activity_count.blank? || athlete_activity_count.zero?
    [(activities_downloaded_count.to_f / athlete_activity_count * 100).round, 100].min
  end

  def gear_names
    return [] if athlete_gear.blank?
    athlete_gear.map { |g| g["name"] }.compact
  end

  def show_gear_link?
    synced? && athlete_gear.present?
  end

  def cycling_gear_ids
    return [] if athlete_gear.blank?
    athlete_gear.select { |g| g["primary"] == true || g["resource_state"].present? }
      .map { |g| g["id"] }.compact
  end

  def update_from_athlete_and_stats(athlete, stats)
    activity_count = if stats
      (stats.dig("all_ride_totals", "count") || 0) +
        (stats.dig("all_run_totals", "count") || 0) +
        (stats.dig("all_swim_totals", "count") || 0)
    end

    update(
      athlete_id: athlete["id"].to_s,
      athlete_activity_count: activity_count,
      athlete_gear: extract_gear(athlete)
    )
  end

  def finish_sync!
    update(status: :synced, activities_downloaded_count: strava_activities.count)
  end

  private

  def extract_gear(athlete)
    bikes = athlete["bikes"] || []
    shoes = athlete["shoes"] || []
    (bikes + shoes).map { |g| g.slice("id", "name", "primary", "distance", "resource_state") }
  end

  def mark_disconnected
    update_columns(status: self.class.statuses[:disconnected])
  end
end
