# frozen_string_literal: true

module API
  class StravaProxyController < ApplicationController
    respond_to :json
    wrap_parameters false
    skip_before_action :verify_authenticity_token
    before_action :cors_preflight_check
    after_action :cors_set_access_control_headers
    rescue_from ArgumentError, with: :render_bad_request

    def create
      auth_response = StravaJobs::ProxyRequester.authorize_user_and_strava_integration(doorkeeper_token)
      if auth_response[:error].present?
        render json: {error: auth_response[:error]}, status: auth_response[:status]
        return
      end

      if !auth_response[:strava_integration].synced? || Binxtils::InputNormalizer.boolean(params[:sync_status])
        render json: StravaJobs::ProxyRequester.sync_status(auth_response[:strava_integration])
        return
      end

      enriched_since = enriched_since_from_url(permitted_params[:url])
      if enriched_since
        activities = auth_response[:strava_integration].strava_activities
          .where("enriched_at > ?", Time.at(enriched_since))
          .map(&:proxy_serialized)
        render json: activities.to_json
        return
      end

      result = StravaJobs::ProxyRequester.create_and_execute(
        strava_integration: auth_response[:strava_integration], user: auth_response[:user],
        url: permitted_params[:url], method: permitted_params[:method], body: permitted_params[:body]&.to_h
      )

      render json: result[:json].to_json, status: result[:status]
    end

    private

    def enriched_since_from_url(url)
      return nil unless url&.match?(/enriched_since=/)
      match = url.match(/enriched_since=(\d+)/)
      match ? match[1].to_i : nil
    end

    def doorkeeper_token
      @doorkeeper_token ||= Doorkeeper::OAuth::Token.authenticate(
        request, *Doorkeeper.configuration.access_token_methods
      )
    end

    def permitted_params
      params.permit(:url, :method, :sync_status, body: {})
    end

    def render_bad_request(exception)
      render json: {error: exception.message}, status: 400
    end
  end
end
