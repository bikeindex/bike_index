class AppointmentMailer < OrganizedMailer
  def view_appointment(appointment)
    @appointment = appointment
    @organization = @appointment.organization
    @location = @appointment.location

    mail(reply_to: reply_to,
         to: @appointment.email,
         subject: "View your place in the #{@organization.short_name} line")
  end
end
