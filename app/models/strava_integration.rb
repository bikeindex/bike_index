# frozen_string_literal: true

# == Schema Information
#
# Table name: strava_integrations
# Database name: primary
#
#  id                          :bigint           not null, primary key
#  access_token                :text             not null
#  activities_downloaded_count :integer          default(0), not null
#  athlete_activity_count      :integer
#  deleted_at                  :datetime
#  last_updated_activities_at  :datetime
#  refresh_token               :text             not null
#  status                      :integer          default("pending"), not null
#  strava_permissions          :string
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
  has_many :strava_gears, dependent: :destroy
  has_many :strava_requests

  enum :status, STATUS_ENUM

  validates :access_token, presence: true, unless: :deleted_at?
  validates :refresh_token, presence: true, unless: :deleted_at?

  before_destroy :mark_disconnected

  def sync_progress_percent
    return 0 if athlete_activity_count.blank? || athlete_activity_count.zero?
    [(activities_downloaded_count.to_f / athlete_activity_count * 100).round, 100].min
  end

  def gear_names
    strava_gears.pluck(:strava_gear_name).compact
  end

  def show_gear_link?
    synced? && strava_gears.any?
  end

  def cycling_gear_ids
    strava_gears.bikes.pluck(:strava_gear_id)
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
      status: :syncing
    )

    bikes = (athlete["bikes"] || []).map { |g| g.merge("gear_type" => "bike") }
    shoes = (athlete["shoes"] || []).map { |g| g.merge("gear_type" => "shoe") }
    (bikes + shoes).each { |gear_data| StravaGear.update_from_strava(self, gear_data) }
  end

  def unknown_gear_ids
    known_ids = strava_gears.pluck(:strava_gear_id)
    strava_activities.where.not(gear_id: [nil, ""] + known_ids).distinct.pluck(:gear_id)
  end

  def gear_ids_to_request
    un_enriched_ids = strava_gears.un_enriched.pluck(:strava_gear_id)
    (unknown_gear_ids + un_enriched_ids).uniq
  end

  def update_sync_status
    calculated_downloaded = strava_activities.count
    return if activities_downloaded_count == calculated_downloaded

    unprocessed = StravaRequest.unprocessed.where(strava_integration_id: id)
    if unprocessed.list_activities.none?
      enqueue_detail_requests
      enqueue_gear_requests
    end

    update(activities_downloaded_count: calculated_downloaded,
      status: unprocessed.none? ? :synced : :syncing)
  end

  private

  def enqueue_gear_requests
    already_enqueued = StravaRequest.unprocessed
      .where(strava_integration_id: id, request_type: :fetch_gear)
      .pluck(Arel.sql("parameters->>'strava_gear_id'"))

    gear_ids_to_request.each do |strava_gear_id|
      next if already_enqueued.include?(strava_gear_id)
      StravaRequest.create!(user_id:, strava_integration_id: id,
        request_type: :fetch_gear, parameters: {strava_gear_id:})
    end
  end

  def enqueue_detail_requests
    already_enqueued = StravaRequest.unprocessed
      .where(strava_integration_id: id, request_type: :fetch_activity)
      .pluck(Arel.sql("parameters->>'strava_activity_id'")).map(&:to_i)
    strava_activities.activities_to_enrich.where.not(id: already_enqueued).pluck(:id, :strava_id).each do |strava_activity_id, strava_id|
      StravaRequest.create!(user_id:, strava_integration_id: id,
        request_type: :fetch_activity, parameters: {strava_id: strava_id.to_s, strava_activity_id:})
    end
  end

  def mark_disconnected
    update_columns(status: self.class.statuses[:disconnected],
      access_token: "", refresh_token: "", token_expires_at: nil)
  end
end
