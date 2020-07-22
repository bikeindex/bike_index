module Organized
  class LinesController < Organized::BaseController
    before_action :ensure_access_to_appointments!
    before_action :assign_current_location, except: [:index]

    def index
      if current_location.present?
        redirect_to organization_line_path(current_location.to_param, organization_id: current_organization.to_param) and return
      end
    end

    def simple_view
      @appointment_configuration
      @tickets = current_location.tickets.in_line
      # @last_ticket_helped = current_location.tickets.resolved.reorder(:resolved_at).last
      render layout: false
    end

    def show
      @appointments = matching_appointments.includes(:appointment_updates)
      @appointment ||= Appointment.new(location_id: current_location.id, organization_id: current_organization.id)
    end

    def update
      if params[:id] == "set_next_ticket"
        update_next_ticket(params[:next_ticket_number])
      elsif params[:status].present?
        if checked_appointment_ids.any?
          permitted_appointments.where(id: checked_appointment_ids).each do |appointment|
            appointment.record_status_update(new_status: params[:status],
                                             updator_kind: "organization_member",
                                             updator_id: current_user.id)
          end
          flash[:success] = "Line updated successfully!"
        else
          flash[:notice] = "Nothing was updated! Did you check any boxes?"
        end
      else
        flash[:error] = "Unknown update action!"
      end
      redirect_to organization_line_path(current_location.to_param, organization_id: current_organization.to_param)
    end

    private

    # assign manually because it's the id parameter, not the location_id parameter
    def assign_current_location
      @current_location = current_organization.locations.friendly_find(params[:id])
    end

    def permitted_appointments
      current_organization.appointments
    end

    def matching_appointments
      current_location.appointments.in_line
    end

    def checked_appointment_ids
      params[:ids]&.keys || []
    end

    def update_next_ticket(next_ticket_number)

    end
  end
end
