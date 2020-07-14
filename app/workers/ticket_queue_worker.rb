class TicketQueueWorker < ApplicationWorker
  DEFAULT_TICKETS_IN_LINE_COUNT = 50
  sidekiq_options queue: "high_priority", retry: 1

  def perform(ticket_id, resolve_earlier_tickets = false)
    ticket = Ticket.find(ticket_id)
    location = ticket.location
    location.tickets.number_ordered.unused
            .where(number: ticket.number...(ticket.number + DEFAULT_TICKETS_IN_LINE_COUNT))
            .update_all(status: "in_line")
    return true unless resolve_earlier_tickets
    location.tickets.number_ordered.in_line
            .where("number < ?", ticket.number)
            .update_all(status: "resolved")
  end
end
