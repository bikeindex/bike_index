module OrganizationPublic
  class CustomerAppointmentsController < OrganizationPublic::BaseController
    # If a user has a link to an appointment, permit it - even if the org no longer has the functionality enabled
    before_action :find_appointment_and_redirect, only: [:show, :set_current]
    before_action :find_appointment, only: [:update]

    layout "customer_virtual_line"

    def show
    end

    def set_current
    end

    def create
      @appointment = Appointment.new(permitted_create_params)
      if @appointment.email.blank?
        flash[:error] = "Email required!"
      elsif @appointment.save
        flash[:success] = "You're now in line!"
        assign_current_appointment(@appointment)
      else
        flash[:error] = @appointment.errors.full_messages.to_sentence
      end
      redirect_to(lines_route) && return
    end

    def update
      if @appointment.removed?
        flash[:error] = "We're sorry, that appointment has been removed"
      elsif @appointment.update(permitted_update_params)
        @appointment.record_status_update(status_update_params)
        assign_current_appointment(@appointment)
        flash[:success] = "Update successful"
      else
        flash[:error] = "Unable to update because: #{@appointment.errors.full_messages.to_sentence}"
      end
      redirect_to lines_route
    end

    private

    def lines_route
      organization_line_path(organization_id: current_organization.to_param,
                             location_id: current_appointment&.location&.to_param || current_location&.to_param)
    end

    def find_appointment
      @appointment_token = params[:appointment_token] || params[:id]
      @appointment ||= current_organization.appointments.find_by_link_token(@appointment_token)
    end

    def find_appointment_and_redirect
      find_appointment
      if @appointment.present?
        # Only assign if the appointment is present, so we don't lose the existing one
        assign_current_appointment(@appointment)
      else
        flash[:error] = "Unable to find that appointment!"
        current_appointment # Grab it if it's around, because at least something
      end
      redirect_to(lines_route) && return
    end

    def permitted_create_params
      params.require(:appointment)
        .permit(:email, :name, :reason, :description, :location_id)
        .merge(organization_id: current_organization.id,
               status: "waiting",
               user_id: current_user&.id,
               creator_kind: current_user.present? ? "signed_in_user" : "no_user")
    end

    def permitted_update_params
      params.require(:appointment)
        .permit(:email, :name, :reason, :description)
        .merge(organization_id: current_organization.id, skip_update: true)
    end

    def status_update_params
      {
        new_status: params.dig(:appointment, :status),
        updator_id: current_user&.id,
        updator_kind: current_user.present? ? "signed_in_user" : "no_user"
      }
    end
  end
end
