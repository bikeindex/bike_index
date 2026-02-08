class StravaRequestRunnerJob < ApplicationJob
  RATE_LIMIT_DELAY = 10.seconds
  ACTIVITIES_PER_PAGE = 200

  sidekiq_options queue: "low_priority", retry: 3

  def perform
    request = StravaRequest.next_pending
    return unless request

    si = StravaIntegration.find_by(id: request.strava_integration_id)
    unless si
      request.update(requested_at: Time.current, response_status: :error)
      enqueue_next
      return
    end

    request.update(requested_at: Time.current)
    response = call_strava_api(si, request)

    if response
      request.update(response_status: :success)
      handle_response(si, request, response)
    else
      request.update(response_status: :error)
    end

    enqueue_next
  end

  private

  def call_strava_api(si, request)
    case request.request_type
    when "fetch_athlete"
      Integrations::Strava.fetch_athlete(si)
    when "fetch_athlete_stats"
      Integrations::Strava.fetch_athlete_stats(si, request.parameters["athlete_id"])
    when "list_activities"
      params = request.parameters.symbolize_keys.slice(:page, :per_page, :after)
      Integrations::Strava.list_activities(si, **params)
    when "fetch_activity"
      Integrations::Strava.fetch_activity(si, request.parameters["strava_id"])
    end
  end

  def handle_response(si, request, response)
    case request.request_type
    when "fetch_athlete"
      handle_fetch_athlete(si, request, response)
    when "fetch_athlete_stats"
      handle_fetch_athlete_stats(si, request, response)
    when "list_activities"
      handle_list_activities(si, request, response)
    when "fetch_activity"
      handle_fetch_activity(si, request, response)
    end
  end

  def handle_fetch_athlete(si, request, athlete)
    create_follow_up(si, :fetch_athlete_stats,
      "athletes/#{athlete["id"]}/stats",
      athlete_id: athlete["id"].to_s, athlete_data: athlete.slice("id", "bikes", "shoes"))
  end

  def handle_fetch_athlete_stats(si, request, stats)
    athlete_data = request.parameters["athlete_data"] || {}
    # Reconstruct minimal athlete hash for update_from_athlete_and_stats
    athlete = {"id" => request.parameters["athlete_id"]}.merge(athlete_data)
    si.update_from_athlete_and_stats(athlete, stats)
    si.update(status: :syncing)

    params = {page: 1, per_page: ACTIVITIES_PER_PAGE}
    params[:after] = request.parameters["after"] if request.parameters["after"]
    create_follow_up(si, :list_activities, "athlete/activities", **params)
  end

  def handle_list_activities(si, request, activities)
    return si.finish_sync! if !activities.is_a?(Array) || activities.blank?

    activities.each { |summary| StravaActivity.create_or_update_from_summary(si, summary) }
    si.update(activities_downloaded_count: si.strava_activities.count)

    if activities.size >= ACTIVITIES_PER_PAGE
      page = (request.parameters["page"] || 1).to_i + 1
      params = {page:, per_page: ACTIVITIES_PER_PAGE}
      params[:after] = request.parameters["after"] if request.parameters["after"]
      create_follow_up(si, :list_activities, "athlete/activities", **params)
    else
      enqueue_detail_requests(si, request.parameters["after"])
    end
  end

  def handle_fetch_activity(si, request, detail)
    activity = si.strava_activities.find_by(id: request.parameters["strava_activity_id"])
    return unless activity

    activity.update_from_detail(detail)

    remaining = StravaRequest.unprocessed.where(strava_integration_id: si.id, request_type: :fetch_activity)
    si.finish_sync! if remaining.none?
  end

  def enqueue_detail_requests(si, after_epoch)
    scope = si.strava_activities.cycling
    scope = scope.where("start_date > ?", Time.at(after_epoch.to_i)) if after_epoch
    activity_ids = scope.pluck(:id, :strava_id)

    if activity_ids.empty?
      si.finish_sync!
      return
    end

    activity_ids.each do |id, strava_id|
      create_follow_up(si, :fetch_activity, "activities/#{strava_id}",
        strava_id: strava_id.to_s, strava_activity_id: id)
    end
  end

  def create_follow_up(si, request_type, endpoint, **params)
    StravaRequest.create!(
      user_id: si.user_id,
      strava_integration_id: si.id,
      request_type:,
      endpoint:,
      parameters: params
    )
  end

  def enqueue_next
    self.class.perform_in(RATE_LIMIT_DELAY) if StravaRequest.next_pending
  end
end
