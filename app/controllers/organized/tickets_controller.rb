module Organized
  class TicketsController < Organized::BaseController
    skip_before_action :ensure_member!, only: [:print]
    before_action :find_tickets, only: [:print]

    def print
      @page_title = "#{current_organization.short_name} Print tickets"
      render layout: false
    end

    private

    def find_tickets
      @tickets = current_location.tickets.limit(10)
    end
  end
end
