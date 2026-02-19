# frozen_string_literal: true

# NOTE: This is not actually a job - it's in the StravaJobs namespace to keep everything together
module StravaJobs
  class ProxyRequester
    STRAVA_DOORKEEPER_APP_ID = ENV.fetch("STRAVA_DOORKEEPER_APP_ID", 3)

    class << self
      # returns {user:, strava_integration:} if valid
      # otherwise {error: message, status: status_code}
      def authorize_user_and_strava_integration(access_token)
        return {status: 401, error: "OAuth token required"} unless access_token&.accessible?
        return {status: 403, error: "Unauthorized application"} unless authorized_app?(access_token)

        user = User.find_by(id: access_token.resource_owner_id)
        return {error: "User not found", status: 401} unless user

        strava_integration = user.strava_integration
        return {error: "No Strava integration", status: 404} unless strava_integration
        return {error: "Strava integration not yet synced - status: #{strava_integration.status}", status: 422} unless strava_integration.synced?

        {user:, strava_integration:}
      end

      def create_and_execute(strava_integration:, user:, url:, method: nil)
        validate_url!(url)
        strava_request = StravaRequest.create!(
          strava_integration:,
          user:,
          request_type: :proxy,
          parameters: {url:, method:}
        )

        response = Integrations::StravaClient.proxy_request(strava_integration,
          strava_request.parameters["url"], method: strava_request.parameters["method"])
        strava_request.update_from_response(response, raise_on_error: false)

        serialized = if strava_request.success?
          handle_proxy_response(strava_integration, response.body)
        end

        {strava_request:, response:, serialized:}
      end

      private

      def authorized_app?(token)
        STRAVA_DOORKEEPER_APP_ID.present? &&
          token.application_id.to_s == STRAVA_DOORKEEPER_APP_ID
      end

      def validate_url!(url)
        raise ArgumentError, "Invalid proxy path" if url.blank? || url.match?(%r{://|\A//|(\A|/)\.\.(/|\z)})
      end

      def handle_proxy_response(strava_integration, body)
        if body.is_a?(Array)
          body.map { |summary| StravaActivity.create_or_update_from_strava_response(strava_integration, summary).proxy_serialized }
        elsif body.is_a?(Hash) && body["sport_type"].present?
          StravaActivity.create_or_update_from_strava_response(strava_integration, body).proxy_serialized
        elsif body.is_a?(Hash) && (body["gear_type"].present? || body.key?("frame_type"))
          StravaGear.update_from_strava(strava_integration, body)
        end
      end
    end
  end
end
