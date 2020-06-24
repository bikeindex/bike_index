class UpdateAppointmentOrderWorker < ApplicationWorker
  sidekiq_options queue: "high_priority", retry: 1

  def perform(location_id, appointment_id = nil)
    location = Location.find(location_id)
    appointment = Appointment.find(appointment_id) if appointment_id.present?
  end
end
