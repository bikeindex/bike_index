# Preview emails at /rails/mailers/organized_mailer
class AppointmentMailerPreview < ActionMailer::Preview
  def view_appointment
    appointment = Appointment.last
    AppointmentsMailer.view_appointment(appointment)
  end
end
