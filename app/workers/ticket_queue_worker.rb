class TicketQueueWorker < ApplicationWorker
  DEFAULT_TICKETS_IN_LINE_COUNT = 50
  sidekiq_options queue: "high_priority", retry: 1

  def perform(location_id, ticket_number = nil)
    if ticket_number.present?
      existing_tickets = location.tickets.line_ordered.where("number >= ?", ticket_number)
      tickets_to_create = DEFAULT_TICKETS_IN_LINE_COUNT - existing_tickets.count
      if tickets_to_create > 0
        initial_number = existing_tickets.max(:number) || ticket_number
        Ticket.create_tickets(tickets_to_create, initial_number: initial_number, location: location)
      end

      first_ticket = location.tickets.line_ordered.unresolved.where("number >= ?", ticket_number).first
      location.tickets.line_ordered.unresolved.where("number < ?", first_ticket.number).each do |ticket|
        # TODO: Make this update the ticket, or the appointment if the ticket is claimed
        ticket.update(status: "removed")
      end
      # location.tickets.line_ordered.where("number >= ?", ticket_number)
      # location.tickets.number_ordered.in_line.where("number < ?", ticket.number).each do |ticket|
      #   if ticket.appointment.present?
      #     ticket.appointment.record_status_update!(new_status: "removed", updator_kind: "queue_worker")
      #   else
      #     ticket.update(status: "resolved")
      #   end
      # end
    end

    location.reload
    (location.appointment_configuration.customers_on_deck_count - location.tickets.paging_or_on_deck.count).times do |i|
      location.reload
      # TODO: Make this update the ticket, or the appointment if the ticket is claimed
      location.tickets.line_not_paging_or_on_deck.first.update(status: "on_deck")
    end
  end
end
