# Preview emails at /rails/mailers/organized_mailer
class AppointmentsMailerPreview < ActionMailer::Preview
  def view_claimed_ticket
    appointment = Appointment.last
    AppointmentsMailer.view_claimed_ticket(appointment)
  end
end
