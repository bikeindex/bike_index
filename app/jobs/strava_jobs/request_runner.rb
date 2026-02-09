module StravaJobs
  class RequestRunner < ScheduledJob
    prepend ScheduledJobRecorder

    sidekiq_options queue: "low_priority", retry: false

    def self.frequency
      16.seconds
    end

    def perform(strava_request_id = nil)
      return enqueue_next_request unless strava_request_id.present?

      request = StravaRequest.find_by(id: strava_request_id)
      return unless request
      return if request.requested_at.present?

      strava_integration = StravaIntegration.find_by(id: request.strava_integration_id)
      unless strava_integration
        request.update(requested_at: Time.current, response_status: :error)
        return
      end

      request.update(requested_at: Time.current)
      response = request.execute(strava_integration)
      request.handle_response(strava_integration, response) if response
    end

    private

    def enqueue_next_request
      request = StravaRequest.next_pending
      self.class.perform_async(request.id) if request
    end
  end
end
