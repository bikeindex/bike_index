class LocationAppointmentsQueueWorker < ApplicationWorker
  sidekiq_options queue: "high_priority", retry: 1

  def perform(location_id)
    location = Location.find(location_id)
    return true unless location.virtual_line_on? && location.appointment_configuration.customers_on_deck_count > 0
    desired_on_deck_count = location.appointment_configuration.customers_on_deck_count

    (desired_on_deck_count - location.tickets.paging_or_on_deck.count).times do |i|
      ticket = location.tickets.line_not_paging_or_on_deck.first
      ticket.create_new_appointment(creator_kind: "queue_worker") unless ticket.appointment.present?
      appointment = ticket.appointment
      appointment.record_status_update(new_status: "on_deck", updator_kind: "queue_worker")
    end
  end
end
