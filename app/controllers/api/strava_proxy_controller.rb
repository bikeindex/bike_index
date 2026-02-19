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
      else
        result = StravaJobs::ProxyRequester.create_and_execute(
          strava_integration: auth_response[:strava_integration], user: auth_response[:user],
          url: permitted_params[:url], method: permitted_params[:method])

        if result[:strava_request].success?
          render json: result[:serialized].to_json, status: result[:response].status
        else
          render json: sanitize_response_body(result[:response]&.body), status: result[:response]&.status || 502
        end
      end
    end

    private

    def doorkeeper_token
      @doorkeeper_token ||= Doorkeeper::OAuth::Token.authenticate(
        request, *Doorkeeper.configuration.access_token_methods
      )
    end

    def permitted_params
      params.permit(:url, :method)
    end

    SENSITIVE_KEYS = %w[access_token refresh_token token client_secret].freeze

    def sanitize_response_body(body)
      return {error: "unknown error"} unless body.is_a?(Hash)
      body.except(*SENSITIVE_KEYS)
    end

    def render_bad_request(exception)
      render json: {error: exception.message}, status: 400
    end
  end
end
