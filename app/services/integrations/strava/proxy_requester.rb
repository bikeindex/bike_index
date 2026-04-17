# frozen_string_literal: true

module Integrations::Strava::ProxyRequester
  extend Functionable

  SENSITIVE_KEYS = %w[access_token refresh_token token client_secret].freeze

  # returns {user:, strava_integration:} if valid
  # otherwise {error: message, status: status_code}
  def authorize_user_and_strava_integration(access_token)
    return {status: 401, error: "OAuth token required"} unless access_token&.accessible?
    return {status: 403, error: "Unauthorized application"} unless authorized_app?(access_token)

    user = User.find_by(id: access_token.resource_owner_id)
    return {error: "User not found", status: 401} unless user

    strava_integration = user.strava_integration
    return {error: "No Strava integration", status: 404} unless strava_integration
    return {error: "Strava authorization failed. Please re-authenticate with Strava.", status: 401} if strava_integration.error?

    {user:, strava_integration:}
  end

  def sync_status(strava_integration)
    {
      sync_status: {
        status: strava_integration.status,
        activities_downloaded_count: strava_integration.activities_downloaded_count,
        athlete_activity_count: strava_integration.athlete_activity_count,
        progress_percent: strava_integration.sync_progress_percent,
        rate_limited: !StravaJobs::ScheduledRequestEnqueuer.rate_limit_allows_batch?
      }
    }
  end

  def create_and_execute(strava_integration:, user:, url:, method: nil, body: nil)
    validate_url!(url)
    request_method = method&.strip&.upcase
    request_method = nil if request_method == "GET"

    strava_request = StravaRequest.create!(
      strava_integration:,
      user:,
      proxy_request: true,
      request_type: proxy_request_type(url, request_method),
      parameters: {url:, method: request_method, body:}.compact
    )

    return internal_response!(strava_request) if internal_response?(strava_request)

    response = StravaJobs::RequestRunner.new.perform(strava_request.id, strava_request:, no_skip: true)
    strava_request.reload

    return {json: Integrations::Strava::Client::RATE_LIMITED_RESPONSE_BODY, status: 429} if response == :rate_limited

    json = if strava_request.success?
      serialize_proxy_response(strava_integration, response.body, method: strava_request.request_method)
    else
      sanitize_response_body(response.body)
    end

    {json:, status: response.status}
  end

  # Returns an existing valid token, or revokes the most recent expired one
  # and creates a new one (matches Doorkeeper's refresh flow)
  def find_or_create_access_token(resource_owner_id)
    application_id = strava_doorkeeper_app_id
    access_token = Doorkeeper::AccessToken
      .where(application_id:, resource_owner_id:)
      .order(id: :desc)
      .detect(&:accessible?)
    return access_token if access_token.present?

    # Revoke and refresh otherwise
    Doorkeeper::AccessToken
      .where(application_id:, resource_owner_id:, revoked_at: nil)
      .order(id: :desc)
      .first&.revoke
    Doorkeeper::AccessToken.create!(
      application_id:,
      resource_owner_id:,
      scopes: "public",
      expires_in: Doorkeeper.configuration.access_token_expires_in
    )
  end

  #
  # private below here
  #

  def internal_response?(strava_request)
    strava_request.fetch_athlete? || strava_request.list_activities?
  end

  def internal_response!(strava_request)
    strava_request.update(response_status: :binx_response, requested_at: Time.current)

    json = if strava_request.fetch_athlete?
      strava_request.strava_integration.proxy_serialized
    else
      page = (strava_request.parameters["url"][/\Wpage=(\d+)/, 1] || 1).to_i - 1
      limit = Integrations::Strava::Client::ACTIVITIES_PER_PAGE

      strava_activities = StravaActivity.where(strava_integration_id: strava_request.strava_integration_id).strava_ordered
      return {json: [], status: 200} if strava_activities.count < page * limit

      strava_activities.offset(page * limit).limit(limit).map(&:proxy_serialized)
    end
    {json:, status: 200}
  end

  def strava_doorkeeper_app_id
    ENV.fetch("STRAVA_DOORKEEPER_APP_ID", 3).to_i
  end

  def authorized_app?(token)
    token.application_id == strava_doorkeeper_app_id
  end

  def proxy_request_type(url, request_method)
    return :update_activity if %w[PUT POST].include?(request_method&.upcase)

    case url
    when /\Aathlete(\/\d+)?\z/ then :fetch_athlete
    when /\Aathlete\/activities/ then :list_activities
    when /\Aactivities\/\d+/ then :fetch_activity
    when /\Agear\// then :fetch_gear
    else
      raise ArgumentError, "Unknown proxy request type for: #{url}, method: #{request_method}"
    end
  end

  def validate_url!(url)
    raise ArgumentError, "Invalid proxy path" if url.blank? || url.match?(%r{://|\A//|(\A|/)\.\.(/|\z)})
  end

  def serialize_proxy_response(strava_integration, body, method: nil)
    if body.is_a?(Array)
      body.map { |summary| StravaActivity.create_or_update_from_strava_response(strava_integration, summary).proxy_serialized }
    elsif body.is_a?(Hash) && body["sport_type"].present?
      strava_activity = StravaActivity.create_or_update_from_strava_response(strava_integration, body)
      if method.to_s.casecmp?("put")
        strava_activity.update_from_strava!(run_inline: true)
        strava_activity.reload
      end
      strava_activity.proxy_serialized
    elsif body.is_a?(Hash) && (body["gear_type"].present? || body.key?("frame_type"))
      StravaGear.update_from_strava(strava_integration, body)
    else
      body
    end
  end

  def sanitize_response_body(body)
    return {error: "unknown error"} unless body.is_a?(Hash)

    body.except(*SENSITIVE_KEYS)
  end

  conceal :strava_doorkeeper_app_id, :internal_response?, :internal_response!,
    :authorized_app?, :proxy_request_type, :validate_url!,
    :serialize_proxy_response, :sanitize_response_body
end
