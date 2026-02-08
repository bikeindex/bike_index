class Integrations::StravaConnection
  BASE_URL = "https://www.strava.com"
  API_URL = "https://www.strava.com/api/v3"
  ACTIVITIES_PER_PAGE = 200
  # Strava rate limits: 100 requests per 15 minutes, 1000 per day
  REQUEST_DELAY = 1.5

  attr_reader :strava_integration

  def initialize(strava_integration)
    @strava_integration = strava_integration
  end

  # Exchange authorization code for tokens
  def self.exchange_token(code)
    conn = oauth_connection
    resp = conn.post("oauth/token") do |req|
      req.body = {
        client_id: ENV["STRAVA_KEY"],
        client_secret: ENV["STRAVA_SECRET"],
        code: code,
        grant_type: "authorization_code"
      }
    end
    return nil unless resp.success?
    resp.body
  end

  def self.authorization_url(redirect_uri)
    params = {
      client_id: ENV["STRAVA_KEY"],
      response_type: "code",
      redirect_uri: redirect_uri,
      scope: "read,activity:read_all",
      approval_prompt: "auto"
    }
    "#{BASE_URL}/oauth/authorize?#{params.to_query}"
  end

  # Fetch athlete profile and update integration with activity count and gear
  def fetch_athlete_and_update
    ensure_valid_token!
    athlete = get("/athlete")
    return false unless athlete

    stats = get("/athletes/#{athlete["id"]}/stats")

    activity_count = if stats
      (stats.dig("all_ride_totals", "count") || 0) +
        (stats.dig("all_run_totals", "count") || 0) +
        (stats.dig("all_swim_totals", "count") || 0)
    end

    strava_integration.update(
      athlete_id: athlete["id"].to_s,
      athlete_activity_count: activity_count,
      athlete_gear: extract_gear(athlete)
    )
  end

  # Download all activities, paginating through the list endpoint.
  # For cycling activities, fetch individual details for extra fields.
  def sync_all_activities
    strava_integration.update(status: "syncing")
    ensure_valid_token!

    page = 1
    downloaded = 0

    loop do
      activities = get("/athlete/activities", per_page: ACTIVITIES_PER_PAGE, page: page)
      break if activities.blank? || !activities.is_a?(Array)

      activities.each do |summary|
        save_activity_from_summary(summary)
        downloaded += 1
        strava_integration.update(activities_downloaded_count: downloaded)
      end

      break if activities.size < ACTIVITIES_PER_PAGE
      page += 1
      sleep(REQUEST_DELAY)
    end

    # For cycling activities, fetch full details for description, photos, location
    fetch_cycling_activity_details

    strava_integration.update(status: "synced")
  rescue => e
    strava_integration.update(status: "error")
    raise e
  end

  private

  def fetch_cycling_activity_details
    strava_integration.strava_activities.cycling.find_each do |activity|
      ensure_valid_token!
      detail = get("/activities/#{activity.strava_id}")
      next unless detail

      activity.update(
        description: detail["description"],
        photos: extract_photos(detail),
        location_city: detail["location_city"],
        location_state: detail["location_state"],
        location_country: detail["location_country"],
        gear_name: detail.dig("gear", "name")
      )

      sleep(REQUEST_DELAY)
    end
  end

  def save_activity_from_summary(summary)
    start_date = Time.parse(summary["start_date"]) rescue nil
    latlng = summary["start_latlng"]

    strava_integration.strava_activities.find_or_initialize_by(strava_id: summary["id"].to_s).tap do |activity|
      activity.assign_attributes(
        title: summary["name"],
        distance: summary["distance"],
        year: start_date&.year,
        gear_id: summary["gear_id"],
        activity_type: summary["type"],
        start_date: start_date,
        start_latitude: latlng&.first,
        start_longitude: latlng&.last
      )
      activity.save!
    end
  end

  def extract_gear(athlete)
    bikes = athlete["bikes"] || []
    shoes = athlete["shoes"] || []
    (bikes + shoes).map { |g| g.slice("id", "name", "primary", "distance", "resource_state") }
  end

  def extract_photos(detail)
    photos_data = detail.dig("photos", "primary")
    return [] unless photos_data

    urls = photos_data["urls"] || {}
    [{id: photos_data["unique_id"], urls: urls}]
  end

  def ensure_valid_token!
    return if strava_integration.token_expires_at.present? && strava_integration.token_expires_at > Time.current

    conn = self.class.oauth_connection
    resp = conn.post("oauth/token") do |req|
      req.body = {
        client_id: ENV["STRAVA_KEY"],
        client_secret: ENV["STRAVA_SECRET"],
        grant_type: "refresh_token",
        refresh_token: strava_integration.refresh_token
      }
    end
    return unless resp.success?

    data = resp.body
    strava_integration.update(
      access_token: data["access_token"],
      refresh_token: data["refresh_token"],
      token_expires_at: Time.at(data["expires_at"])
    )
  end

  def get(path, params = {})
    ensure_valid_token!
    resp = api_connection.get(path) do |req|
      req.params = params
    end
    return nil unless resp.success?
    resp.body
  end

  def api_connection
    @api_connection ||= Faraday.new(url: API_URL) do |conn|
      conn.request :json
      conn.response :json, content_type: /\bjson$/
      conn.adapter Faraday.default_adapter
      conn.headers["Authorization"] = "Bearer #{strava_integration.access_token}"
      conn.options.timeout = 30
    end
  end

  def self.oauth_connection
    Faraday.new(url: BASE_URL) do |conn|
      conn.request :url_encoded
      conn.response :json, content_type: /\bjson$/
      conn.adapter Faraday.default_adapter
      conn.options.timeout = 15
    end
  end
end
