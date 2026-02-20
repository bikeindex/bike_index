# frozen_string_literal: true

class StravaSearchController < ApplicationController
  before_action :store_return_and_authenticate_user, only: [:index]

  def index
    unless current_user.strava_integration
      return redirect_to new_strava_integration_path
    end

    @strava_search_config = {
      tokenEndpoint: strava_search_token_path,
      proxyEndpoint: api_strava_proxy_index_path,
      athleteId: current_user.strava_integration.athlete_id
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

    app_id = StravaJobs::ProxyRequester::STRAVA_DOORKEEPER_APP_ID
    access_token = Doorkeeper::AccessToken.create!(
      application_id: app_id,
      resource_owner_id: current_user.id,
      scopes: "public",
      expires_in: Doorkeeper.configuration.access_token_expires_in
    )

    render json: {
      access_token: access_token.token,
      expires_in: access_token.expires_in,
      created_at: access_token.created_at.to_i,
      athlete_id: strava_integration.athlete_id
    }
  end
end
