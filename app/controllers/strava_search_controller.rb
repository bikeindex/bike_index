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

    application_id = StravaJobs::ProxyRequester::STRAVA_DOORKEEPER_APP_ID
    access_token = find_valid_token(application_id, current_user.id)

    # No valid token — refresh the most recent expired one, or create new
    unless access_token
      access_token = Doorkeeper::AccessToken
        .where(application_id:, resource_owner_id: current_user.id, revoked_at: nil)
        .order(created_at: :desc)
        .first
      if access_token
        access_token.update!(created_at: Time.current, expires_in: Doorkeeper.configuration.access_token_expires_in)
      else
        access_token = Doorkeeper::AccessToken.create!(
          application_id:,
          resource_owner_id: current_user.id,
          scopes: "public",
          expires_in: Doorkeeper.configuration.access_token_expires_in
        )
      end
    end

    render json: {
      access_token: access_token.token,
      expires_in: access_token.expires_in,
      created_at: access_token.created_at.to_i,
      athlete_id: strava_integration.athlete_id
    }
  end

  private

  def handle_unverified_request
    render json: {error: "CSRF verification failed"}, status: 422
  end

  def find_valid_token(application_id, resource_owner_id)
    Doorkeeper::AccessToken
      .where(application_id:, resource_owner_id:)
      .order(created_at: :desc)
      .detect(&:accessible?)
  end
end
