
class LocationAppointmentsQueueWorker < ApplicationWorker
  sidekiq_options queue: "high_priority", retry: 1

  def perform(location_id)
    location = Location.find(location_id)
    return true unless location.virtual_line_on? && location.appointment_configuration.customers_on_deck_count > 0
    customers_on_deck_count = location.appointment_configuration.customers_on_deck_count
    if location.appointments.in_line.count == location.appointments.on_deck.count
      return true if location.appointments.in_line.count <= customers_on_deck_count
    end
    current_on_deck_ids = []
    customers_on_deck_count.times do |i|
      appointment = location.appointments.in_line[i]
      current_on_deck_ids << appointment.id
      next if appointment.status == "on_deck"
      appointment.update(status: "on_deck", skip_update: true)
    end
    location.reload
    location.appointments.on_deck.where.not(id: current_on_deck_ids)
      .update_all(status: "waiting")
  end
end
