
class LocationAppointmentsQueueWorker < ApplicationWorker
  sidekiq_options queue: "high_priority", retry: 1

  def perform(location_id)
    location = Location.find(location_id)
  end
end
