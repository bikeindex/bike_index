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
      elsif @ticket.present? # unclaimed ticket
        @appointment = @ticket.new_appointment
      end

      @tickets_in_line = current_location.tickets.in_line
    end

    def create
      ticket = current_organization.tickets.friendly_find(params[:ticket_number])
      appointment = ticket&.appointment
      if ticket.blank? || ticket.unused?
        flash[:error] = "That ticket doesn't appear to be in line, please enter a different number"
      elsif ticket.resolved? || appointment&.no_longer_in_line?
        flash[:info] = ticket_resolved_message(ticket)
      elsif ticket.claimed?
        @current_location = ticket.location
        Notification.create_for("view_claimed_ticket", appointment: appointment)
        flash[:info] = "That ticket has already been claimed. Please follow the link we sent to update your place in line"
      else
        assign_current_ticket(ticket)
      end
      redirect_to organization_virtual_line_index_path(organization_id: current_organization.to_param, location_id: current_location&.to_param)
    end

    def update
      if @ticket.blank?
        flash[:error] = "Unable to find that ticket"
      elsif @ticket.resolved? || @appointment&.no_longer_in_line?
        assign_current_ticket(nil)
        flash[:error] = ticket_resolved_message(ticket)
      else
        if @ticket.unclaimed?
          @ticket.claim(user: current_user, email: params.dig(:appointment, :email), creation_ip: forwarded_ip_address)
        end
        if @ticket.errors.present?
          flash[:error] = @ticket.errors.full_messages.to_sentence
          assign_current_ticket(nil)
        else
          @ticket.appointment.user ||= current_user
          @ticket.appointment.update(permitted_params)
          @ticket.appointment.record_status_update(status_update_params) if current_user.present?
          assign_current_ticket(@ticket)
          flash[:success] = "Ticket is claimed!"
        end
      end
      redirect_to organization_virtual_line_index_path(organization_id: current_organization.to_param, location_id: current_location&.to_param)
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

    def ticket_resolved_message(ticket)
      if ticket.appointment&.present?
        ticket_verb = "helped already" if ticket.appointment.being_helped?
        ticket_verb = "marked abandoned" if ticket.appointment.abandoned?
      end
      "That ticket was in line, but was #{ticket_verb || "resolved"}"
    end

    def assign_current_ticket(ticket = nil)
      session[:ticket_token] = ticket&.link_token
      @ticket = ticket
      @appointment = ticket&.appointment
      @current_location = ticket&.location if @ticket.present?
      @ticket
    end

    def permitted_params
      params.require(:appointment)
        .permit(:email, :name, :reason, :description)
        .merge(skip_update: current_user.present?) # Skip update if current_user present, because we'll record a status update
    end

    def status_update_params
      {
        new_status: params.dig(:appointment, :status),
        updator_id: current_user&.id,
        updator_kind: current_user.present? ? "signed_in_user" : "no_user",
      }
    end
  end
end
