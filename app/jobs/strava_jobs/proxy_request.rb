# frozen_string_literal: true

# NOTE: THis is not actually a job - it's in the StravaJobs namespace to keep everything together
module StravaJobs
  class ProxyRequest
    class << self
      def create_and_execute(strava_integration:, user:, url:, method: nil)
        strava_request = StravaRequest.create!(
          strava_integration:,
          user:,
          request_type: :proxy,
          parameters: {url: , method:}
        )

        response = Integrations::StravaClient.proxy_request(strava_integration,
          strava_request.parameters["url"], method: parameters["method"])
        handle_proxy_response(strava_integration, response)
        response
      end

      private

      def handle_proxy_response(strava_integration, response)
        if response.is_a?(Array)
          response.each { |summary| StravaActivity.create_or_update_from_strava_response(strava_integration, summary) }
        elsif response.is_a?(Hash) && response["sport_type"].present?
          StravaActivity.create_or_update_from_strava_response(strava_integration, response)
        elsif response.is_a?(Hash) && response["gear_type"].present?
          StravaGear.update_from_strava(strava_integration, response)
        end
      end
    end
  end
end
