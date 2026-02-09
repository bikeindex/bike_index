class StravaRequestRunnerJob < ApplicationJob
  RATE_LIMIT_DELAY = 10.seconds

  sidekiq_options queue: "low_priority", retry: 3

  def perform
    request = StravaRequest.next_pending
    return unless request

    strava_integration = StravaIntegration.find_by(id: request.strava_integration_id)
    unless strava_integration
      request.update(requested_at: Time.current, response_status: :error)
      enqueue_next
      return
    end

    request.update(requested_at: Time.current)
    response = request.execute(strava_integration)

    if response
      request.update(response_status: :success)
      request.handle_response(strava_integration, response)
    else
      request.update(response_status: :error)
    end

    enqueue_next
  end

  private

  def enqueue_next
    self.class.perform_in(RATE_LIMIT_DELAY) if StravaRequest.next_pending
  end
end
