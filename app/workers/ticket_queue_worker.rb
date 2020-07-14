class TicketQueueWorker < ApplicationWorker
  DEFAULT_TICKETS_IN_LINE_COUNT = 50
  sidekiq_options queue: "high_priority", retry: 1

  def perform(ticket_id, resolve_earlier_tickets = false)
    ticket = Ticket.find(ticket_id)
    location = ticket.location
    location.tickets.number_ordered.unused
            .where(number: ticket.number...(ticket.number + DEFAULT_TICKETS_IN_LINE_COUNT))
            .update_all(status: "waiting")
    if resolve_earlier_tickets
      location.tickets.number_ordered.in_line.where("number < ?", ticket.number).each do |ticket|
        if ticket.appointment.present?
          ticket.appointment.record_status_update!(new_status: "removed", updator_kind: "queue_worker")
        else
          ticket.update(status: "resolved")
        end
      end
    end
    # And then run location appoaintments queue worker
    LocationAppointmentsQueueWorker.new.perform(ticket.location_id)
  end
end
