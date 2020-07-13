class CustomerAppointmentsMailer < OrganizedMailer
  def view_claimed_ticket(ticket)
    @ticket = ticket
    @appointment = @ticket.appointment
    @organization = @appointment.organization
    @location = @appointment.location

    mail(reply_to: reply_to,
         to: @appointment.email,
         subject: "View your place in the #{@organization.short_name} line")
  end
end
