class AppointmentsMailer < OrganizedMailer
  def view_claimed_ticket(appointment)
    @appointment = appointment
    @ticket = @appointment.ticket
    @organization = @appointment.organization
    @location = @appointment.location

    mail(reply_to: reply_to,
         to: @appointment.email,
         subject: "View your place in the #{@organization.short_name} line")
  end
end
