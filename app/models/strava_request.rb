# == Schema Information
#
# Table name: strava_requests
# Database name: analytics
#
#  id                    :bigint           not null, primary key
#  endpoint              :string           not null
#  parameters            :jsonb
#  request_type          :integer          not null
#  requested_at          :datetime
#  response_status       :integer          default("pending"), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  strava_integration_id :bigint           not null
#  user_id               :bigint
#
# Indexes
#
#  index_strava_requests_on_strava_integration_id_and_requested_at  (strava_integration_id,requested_at)
#  index_strava_requests_on_user_id                                 (user_id)
#
class StravaRequest < AnalyticsRecord
  REQUEST_TYPE_ENUM = {fetch_athlete: 0, fetch_athlete_stats: 1, list_activities: 2, fetch_activity: 3}.freeze
  RESPONSE_STATUS_ENUM = {pending: 0, success: 1, error: 2, rate_limited: 3, token_refresh_failed: 4}.freeze
  ACTIVITIES_PER_PAGE = 200

  enum :request_type, REQUEST_TYPE_ENUM
  enum :response_status, RESPONSE_STATUS_ENUM

  validates :strava_integration_id, presence: true
  validates :endpoint, presence: true

  scope :unprocessed, -> { where(requested_at: nil).order(:created_at) }

  def self.next_pending
    unprocessed.first
  end

  def self.create_follow_up(strava_integration, request_type, endpoint, **params)
    create!(
      user_id: strava_integration.user_id,
      strava_integration_id: strava_integration.id,
      request_type:,
      endpoint:,
      parameters: params
    )
  end

  def execute(strava_integration)
    response = case request_type
    when "fetch_athlete"
      Integrations::Strava.fetch_athlete(strava_integration)
    when "fetch_athlete_stats"
      Integrations::Strava.fetch_athlete_stats(strava_integration, parameters["athlete_id"])
    when "list_activities"
      params = parameters.symbolize_keys.slice(:per_page, :before, :after)
      Integrations::Strava.list_activities(strava_integration, **params)
    when "fetch_activity"
      Integrations::Strava.fetch_activity(strava_integration, parameters["strava_id"])
    end

    if response.success?
      update(response_status: :success)
      response.body
    elsif response.status == 429
      update(response_status: :rate_limited)
      nil
    elsif response.status == 401
      update(response_status: :token_refresh_failed)
      nil
    else
      update(response_status: :error)
      raise "Strava API error #{response.status}: #{response.body}"
    end
  end

  def handle_response(strava_integration, response)
    case request_type
    when "fetch_athlete" then handle_fetch_athlete(strava_integration, response)
    when "fetch_athlete_stats" then handle_fetch_athlete_stats(strava_integration, response)
    when "list_activities" then handle_list_activities(strava_integration, response)
    when "fetch_activity" then handle_fetch_activity(strava_integration, response)
    end
  end

  private

  def handle_fetch_athlete(strava_integration, athlete)
    self.class.create_follow_up(strava_integration, :fetch_athlete_stats,
      "athletes/#{athlete["id"]}/stats",
      athlete_id: athlete["id"].to_s, athlete_data: athlete.slice("id", "bikes", "shoes"))
  end

  def handle_fetch_athlete_stats(strava_integration, stats)
    athlete_data = parameters["athlete_data"] || {}
    athlete = {"id" => parameters["athlete_id"]}.merge(athlete_data)
    strava_integration.update_from_athlete_and_stats(athlete, stats)
    strava_integration.update(status: :syncing)

    params = {per_page: ACTIVITIES_PER_PAGE}
    params[:after] = parameters["after"] if parameters["after"]
    self.class.create_follow_up(strava_integration, :list_activities, "athlete/activities", **params)
  end

  def handle_list_activities(strava_integration, activities)
    return strava_integration.finish_sync! if !activities.is_a?(Array) || activities.blank?

    activities.each { |summary| StravaActivity.create_or_update_from_summary(strava_integration, summary) }
    strava_integration.update(activities_downloaded_count: strava_integration.strava_activities.count)

    if activities.size >= ACTIVITIES_PER_PAGE
      oldest_start = activities.filter_map { |a| a["start_date"] }.min
      before_epoch = oldest_start ? Time.parse(oldest_start).to_i : nil
      params = {per_page: ACTIVITIES_PER_PAGE}
      params[:before] = before_epoch if before_epoch
      params[:after] = parameters["after"] if parameters["after"]
      self.class.create_follow_up(strava_integration, :list_activities, "athlete/activities", **params)
    else
      enqueue_detail_requests(strava_integration)
    end
  end

  def handle_fetch_activity(strava_integration, detail)
    activity = strava_integration.strava_activities.find_by(id: parameters["strava_activity_id"])
    return unless activity

    activity.update_from_detail(detail)

    remaining = self.class.unprocessed.where(strava_integration_id: strava_integration.id, request_type: :fetch_activity)
    strava_integration.finish_sync! if remaining.none?
  end

  def enqueue_detail_requests(strava_integration)
    after_epoch = parameters["after"]
    scope = strava_integration.strava_activities.cycling
    scope = scope.where("start_date > ?", Time.at(after_epoch.to_i)) if after_epoch
    activity_ids = scope.pluck(:id, :strava_id)

    if activity_ids.empty?
      strava_integration.finish_sync!
      return
    end

    activity_ids.each do |id, strava_id|
      self.class.create_follow_up(strava_integration, :fetch_activity, "activities/#{strava_id}",
        strava_id: strava_id.to_s, strava_activity_id: id)
    end
  end
end
