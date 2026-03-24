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
#  strava_data                 :jsonb
#  strava_permissions          :string
#  token_expires_at            :datetime
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  strava_id                   :string
#  user_id                     :bigint           not null
#
# Indexes
#
#  index_strava_integrations_on_deleted_at  (deleted_at)
#  index_strava_integrations_on_user_id     (user_id) UNIQUE WHERE (deleted_at IS NULL)
#
class StravaIntegration < ApplicationRecord
  STATUS_ENUM = {pending: 0, syncing: 1, synced: 2, error: 3}.freeze
  DEFAULT_SCOPE_COUNT = Integrations::Strava::Client::DEFAULT_SCOPE.count(",")

  acts_as_paranoid

  enum :status, STATUS_ENUM

  belongs_to :user

  has_many :strava_activities, dependent: :destroy
  has_many :strava_gears, dependent: :destroy
  has_many :strava_requests

  validates :access_token, presence: true, unless: :deleted_at?
  validates :refresh_token, presence: true, unless: :deleted_at?

  before_destroy :mark_disconnected

  scope :token_expired, -> { where("token_expires_at IS NULL OR token_expires_at < ?", Time.current) }
  scope :permissions_default, -> { where(strava_permissions: Integrations::Strava::Client::DEFAULT_SCOPE) }
  scope :permissions_less, -> {
    where("strava_permissions IS NULL OR LENGTH(strava_permissions) - LENGTH(REPLACE(strava_permissions, ',', '')) < ?", DEFAULT_SCOPE_COUNT)
  }
  scope :permissions_more, -> {
    where.not(strava_permissions: [nil, ""]).where("LENGTH(strava_permissions) - LENGTH(REPLACE(strava_permissions, ',', '')) > ?", DEFAULT_SCOPE_COUNT)
  }

  def token_expired?
    token_expires_at.nil? || token_expires_at < Time.current
  end

  def permissions_default?
    strava_permissions == Integrations::Strava::Client::DEFAULT_SCOPE
  end

  def permissions_strava_search_default?
    strava_permissions == Integrations::Strava::Client::STRAVA_SEARCH_SCOPE
  end

  def permissions_less?
    return true if strava_permissions.blank?

    strava_permissions.split(",").length < Integrations::Strava::Client::DEFAULT_SCOPE.split(",").length
  end

  def permissions_more?
    strava_permissions.present? && strava_permissions.split(",").length > Integrations::Strava::Client::DEFAULT_SCOPE.split(",").length
  end

  def has_activity_write?
    strava_permissions.present? && strava_permissions.split(",").include?("activity:write")
  end

  def sync_progress_percent
    return 0 if athlete_activity_count.blank? || athlete_activity_count.zero?
    [(activities_downloaded_count.to_f / athlete_activity_count * 100).round, 100].min
  end

  def show_gear_link?
    (synced? || syncing?) && strava_gears.bikes.any?
  end

  def proxy_serialized
    (strava_data || {}).merge("id" => strava_id, "bikes" => strava_gears.bikes.map(&:proxy_serialized),
      "shoes" => strava_gears.shoes.map(&:proxy_serialized))
  end

  def update_from_athlete_and_stats(athlete, stats = nil)
    if stats
      self.athlete_activity_count = (stats.dig("all_ride_totals", "count") || 0) +
        (stats.dig("all_run_totals", "count") || 0) +
        (stats.dig("all_swim_totals", "count") || 0)
    end
    update(strava_data: athlete.except("id"), strava_id: athlete["id"], status: calculated_status)

    bikes = (athlete["bikes"] || []).map { |g| g.merge("gear_type" => "bike") }
    shoes = (athlete["shoes"] || []).map { |g| g.merge("gear_type" => "shoe") }
    (bikes + shoes).each { |gear_data| StravaGear.update_from_strava(self, gear_data) }
  end

  def update_sync_status(force_update: false)
    calculated_downloaded = strava_activities.count
    return if !force_update && activities_downloaded_count == calculated_downloaded && synced?

    self.status = calculated_status
    # Update before enqueuing the enrich requests, to make double enqueuing less likely
    update!(activities_downloaded_count: calculated_downloaded)

    StravaJobs::EnqueueEnrichActivities.perform_async(id) if synced?
  end

  def unknown_gear_ids
    known_ids = strava_gears.pluck(:strava_id)
    strava_activities.where.not(gear_id: [nil, ""] + known_ids).distinct.pluck(:gear_id)
  end

  def gear_ids_to_request
    un_enriched_ids = strava_gears.un_enriched.pluck(:strava_id)
    (unknown_gear_ids + un_enriched_ids).uniq
  end

  private

  def calculated_status
    return :error if status == :error
    return :syncing if strava_requests.list_activities.count == 0

    if strava_requests.list_activities.pending.count > 0
      :syncing
    else
      :synced
    end
  end

  def mark_disconnected
    update_columns(access_token: "", refresh_token: "", token_expires_at: nil,
      activities_downloaded_count: 0)
  end
end
