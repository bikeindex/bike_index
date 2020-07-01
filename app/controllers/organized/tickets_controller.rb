module Organized
  class TicketsController < Organized::BaseController
    skip_before_action :ensure_member!, only: [:print]
    before_action :find_tickets, only: [:print]

    def print
      render layout: false
    end

    private

    def find_tickets
      @tickets = current_location.tickets
    end
  end
end
