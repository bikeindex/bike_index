module OrgPublic
  class VirtualLineController < OrgPublic::BaseController
    before_action :find_ticket, except: [:create]
    before_action :ensure_access_to_virtual_line!

    layout "virtual_line"

    def index
      # If the appointment isn't in line, update so they can create a new appointment
      if @ticket&.resolved? || @appointment&.no_longer_in_line?
        flash[:info] = "Your last ticket is no longer in line!"
        assign_current_ticket(nil)
      elsif @ticket&.claimed?
        assign_current_ticket(@ticket)
      end
    end

    def create
      ticket = current_organization.tickets.friendly_find(params[:ticket_number])
      appointment = ticket&.appointment
      if ticket.blank?
        flash[:error] = "That ticket doesn't appear to be in line, please enter a different number"
      elsif ticket.resolved? || appointment&.no_longer_in_line?
        if appointment&.present?
          ticket_verb = "helped already" if appointment.being_helped?
          ticket_verb = "marked abandoned" if appointment.abandoned?
        end
        flash[:info] = "That ticket was in line, but was #{ticket_verb || 'resolved'}"
      elsif ticket.claimed?
        @current_location = ticket.location
        Notification.create_for("view_claimed_ticket", appointment: appointment)
        flash[:info] = "That ticket has already been claimed. Please follow the link we sent to update your place in line"
      else
        flash[:success] = "You've claimed your place in line"
        assign_current_ticket(ticket)
      end
      redirect_to organization_virtual_line_index_path(organization_id: current_organization.to_param, location_id: current_location&.to_param)
    end

    def update
    end

    private

    def find_ticket
      @ticket_token ||= params[:ticket_token] || session[:ticket_token]
      if @ticket_token.present?
        @ticket = current_organization.tickets.find_by_link_token(@ticket_token)
        @appointment = @ticket&.appointment
      end
      @current_location = @ticket&.location if @ticket.present?
      @current_ticket = @ticket
    end

    def assign_current_ticket(ticket = nil)
      session[:ticket_token] = ticket&.link_token
      @ticket = ticket
      @appointment = ticket&.appointment
      @current_location = ticket&.location if @ticket.present?
      @ticket
    end
  end
end
