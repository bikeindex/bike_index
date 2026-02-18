# frozen_string_literal: true

# NOTE: This is not actually a job - it's in the StravaJobs namespace to keep everything together
module StravaJobs
  class ProxyRequest
    class << self
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

        if strava_request.success?
          handle_proxy_response(strava_integration, response.body)
        end

        {strava_request:, response:}
      end

      private

      def validate_url!(url)
        raise ArgumentError, "Invalid proxy path" if url.blank? || url.match?(%r{://|\A//|(\A|/)\.\.(/|\z)})
      end

      def handle_proxy_response(strava_integration, body)
        if body.is_a?(Array)
          body.each { |summary| StravaActivity.create_or_update_from_strava_response(strava_integration, summary) }
        elsif body.is_a?(Hash) && body["sport_type"].present?
          StravaActivity.create_or_update_from_strava_response(strava_integration, body)
        elsif body.is_a?(Hash) && (body["gear_type"].present? || body.key?("frame_type"))
          StravaGear.update_from_strava(strava_integration, body)
        end
      end
    end
  end
end
