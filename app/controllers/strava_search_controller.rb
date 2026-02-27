# frozen_string_literal: true

class StravaSearchController < ApplicationController
  content_security_policy false, only: [:index]
  before_action :store_return_and_authenticate_user, only: [:index]

  def index
    unless current_user.strava_integration
      return redirect_to new_strava_integration_path(scope: :strava_search)
    end

    strava_integration = current_user.strava_integration
    @strava_search_config = {
      tokenEndpoint: strava_search_token_path,
      proxyEndpoint: api_strava_proxy_index_path,
      athleteId: strava_integration.athlete_id,
      hasActivityWrite: strava_integration.has_activity_write?,
      authUrl: new_strava_integration_path(scope: :strava_search)
    }
    @strava_search_assets = if ENV["BUILD_STRAVA_SEARCH"] == "true"
      [{type: :script, src: "http://localhost:3143/strava_search/@vite/client"},
        {type: :react_refresh, src: "http://localhost:3143/strava_search/@react-refresh"},
        {type: :script, src: "http://localhost:3143/strava_search/src/main.tsx"}]
    else
      Dir.glob(Rails.root.join("public/strava_search/assets/*")).filter_map do |file|
        basename = File.basename(file)
        if basename.end_with?(".js")
          {type: :script, src: "/strava_search/assets/#{basename}"}
        elsif basename.end_with?(".css")
          {type: :stylesheet, href: "/strava_search/assets/#{basename}"}
        end
      end
    end
  end

  def create_token
    return render json: {error: "Authentication required"}, status: 401 unless current_user

    strava_integration = current_user.strava_integration
    return render json: {error: "No Strava integration"}, status: 404 unless strava_integration

    access_token = StravaJobs::ProxyRequester.find_or_create_access_token(current_user.id)

    result = {
      access_token: access_token.token,
      expires_in: access_token.expires_in,
      created_at: access_token.created_at.to_i,
      athlete_id: strava_integration.athlete_id
    }

    unless strava_integration.synced?
      result[:sync_status] = {
        status: strava_integration.status,
        activities_downloaded_count: strava_integration.activities_downloaded_count,
        athlete_activity_count: strava_integration.athlete_activity_count,
        progress_percent: strava_integration.sync_progress_percent
      }
    end

    render json: result
  end

  private

  def handle_unverified_request
    render json: {error: "CSRF verification failed"}, status: 422
  end
end
