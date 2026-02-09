module StravaJobs
  class InitialSync < ApplicationJob
    sidekiq_options queue: "low_priority", retry: 3

    def perform(strava_integration_id)
      return if skip_job?

      strava_integration = StravaIntegration.find_by(id: strava_integration_id)
      return unless strava_integration

      request = StravaRequest.create!(
        user_id: strava_integration.user_id,
        strava_integration_id: strava_integration.id,
        request_type: :fetch_athlete,
        endpoint: "athlete"
      )
      StravaJobs::RequestRunner.new.perform(request.id)
    end
  end
end
