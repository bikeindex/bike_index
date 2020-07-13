module OrgPublic
  class VirtualLineController < OrgPublic::BaseController
    before_action :find_ticket
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
      session.keys
    end

    def create
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
      @current_location = @appointment.location if @appointment.present?
      @current_ticket = @ticket
    end

    def assign_current_ticket(ticket = nil)
      session[:ticket_token] = ticket&.link_token
      @ticket = ticket
      @appointment = ticket&.appointment
      @current_location = @appointment.location if @appointment.present?
      @ticket
    end

    # def current_ticket
    #   return @current_appointment if defined?(@current_appointment)
    #   @appointment_token ||= params[:appointment_token] || session[:appointment_token]
    #   @appointment_token ||= params[:appointment_token] || session[:appointment_token]
    #   @current_appointment = current_organization.appointments.find_by_link_token(@appointment_token)
    #   @current_location = @current_appointment.location if @current_appointment.present?
    #   @current_ticket = @appointment.ticket
    #   @current_appointment
    # end

    # def current_appointment
    #   return @current_appointment if defined?(@current_appointment)
    #   if @current_ticket.present?
    #   @appointment_token ||= params[:appointment_token] || session[:appointment_token]
    #   @appointment_token ||= params[:appointment_token] || session[:appointment_token]
    #   @current_appointment = current_organization.appointments.find_by_link_token(@appointment_token)
    #   @current_location = @current_appointment.location if @current_appointment.present?
    #   @current_ticket = @appointment.ticket
    #   @current_appointment
    # end

    # def assign_current_appointment(appointment = nil)
    #   session[:appointment_token] = appointment.present? ? appointment.link_token : nil
    #   return nil unless appointment.present?
    #   @current_location = appointment.location
    #   @current_appointment = appointment
    # end
  end
end
