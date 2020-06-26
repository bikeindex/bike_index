class LocationAppointmentsQueueWorker < ApplicationWorker
  sidekiq_options queue: "high_priority", retry: 1

  def perform(location_id)
    location = Location.find(location_id)
    return true unless location.virtual_line_on? && location.appointment_configuration.customers_on_deck_count > 0
    desired_on_deck_count = location.appointment_configuration.customers_on_deck_count
    # if location.appointments.in_line.count == location.appointments.on_deck_or_paging.count
    #   return true if location.appointments.in_line.count <= desired_on_deck_count
    # end

    # pp desired_on_deck_count, location.appointments.on_deck_or_paging.count, (desired_on_deck_count - location.appointments.on_deck_or_paging.count), "----"

    (desired_on_deck_count - location.appointments.on_deck_or_paging.count).times do |i|
      appointment = location.appointments.not_on_deck_or_paging.first
      appointment.record_status_update!(new_status: "on_deck", updator_kind: "queue_worker")
    end
  end
end
