# frozen_string_literal: true

module API
  class StravaProxyController < ApplicationController
    STRAVA_DOORKEEPER_APP_ID = ENV.fetch("STRAVA_DOORKEEPER_APP_ID", 3)

    respond_to :json
    wrap_parameters false
    skip_before_action :verify_authenticity_token
    before_action :cors_preflight_check
    after_action :cors_set_access_control_headers
    rescue_from ArgumentError, with: :render_bad_request

    def create
      access_token = doorkeeper_token
      return render json: {error: "OAuth token required"}, status: 401 unless access_token&.accessible?
      return render json: {error: "Unauthorized application"}, status: 403 unless authorized_app?(access_token)

      user = User.find_by(id: access_token.resource_owner_id)
      return render json: {error: "User not found"}, status: 401 unless user

      strava_integration = user.strava_integration
      return render json: {error: "No Strava integration"}, status: 404 unless strava_integration

      result = StravaJobs::ProxyRequest.create_and_execute(strava_integration:, user:,
        url: permitted_params[:url], method: permitted_params[:method])
      render_proxy_response(result)
    end

    private

    def doorkeeper_token
      @doorkeeper_token ||= Doorkeeper::OAuth::Token.authenticate(
        request, *Doorkeeper.configuration.access_token_methods
      )
    end

    def authorized_app?(token)
      STRAVA_DOORKEEPER_APP_ID.present? &&
        token.application_id.to_s == STRAVA_DOORKEEPER_APP_ID
    end

    def permitted_params
      params.permit(:url, :method)
    end

    def render_proxy_response(result)
      strava_request = result[:strava_request]
      strava_response = result[:response]
      unless strava_request.success?
        return render json: {error: strava_request.response_status}, status: strava_response&.status || 502
      end
      render body: result[:serialized].to_json, content_type: "application/json", status: strava_response.status
    end

    def render_bad_request(exception)
      render json: {error: exception.message}, status: 400
    end
  end
end
