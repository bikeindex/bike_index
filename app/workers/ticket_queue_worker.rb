class TicketQueueWorker < ApplicationWorker
  DEFAULT_TICKETS_IN_LINE_COUNT = 50
  sidekiq_options queue: "high_priority", retry: 1

  def perform(location_id, ticket_number: nil, skip_resolving_earlier_tickets: false)
    unless ticket
    if ticket_id.present?
    ticket = Ticket.find(ticket_id)
    location = ticket.location
    location.tickets.number_ordered.unused
            .where(number: ticket.number...(ticket.number + DEFAULT_TICKETS_IN_LINE_COUNT))
            .update_all(status: "waiting")
    unless skip_resolving_earlier_tickets
      location.tickets.number_ordered.in_line.where("number < ?", ticket.number).each do |ticket|
        if ticket.appointment.present?
          ticket.appointment.record_status_update!(new_status: "removed", updator_kind: "queue_worker")
        else
          ticket.update(status: "resolved")
        end
      end
    end
  end
end
