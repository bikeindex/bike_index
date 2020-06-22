module OrgPublic
  class CustomerAppointmentsController < OrgPublic::BaseController
    # If a user has a link to an appointment, render it - even if the org no longer has the functionality enabled
    before_action :ensure_access_to_virtual_line!, only: [:create]
    before_action :find_appointment_and_redirect, only: [:show, :set_current_appointment]

    layout "customer_virtual_line"

    def show; end

    def set_current_appointment; end

    def create
      @appointment = Appointment.create(permitted_create_params)
    end

    def update
      redirect_to path_to_redirect_to
    end

    private

    def customer_line_path
      organization_customer_line_path(organization_id: current_organization.to_param,
                                      location_id: current_appointment&.location&.to_param)
    end

    def find_appointment_and_redirect
      @appointment ||= current_organization.appointments.find_by_link_token(params[:id])
      if @appointment.present?
        # Only assign if the appointment is present, so we don't lose the existing one
        assign_current_appointment(@appointment)
      else
        flash[:error] = "Unable to find that appointment!"
        current_appointment # Grab it if it's around, because at least something
      end
      redirect_to customer_line_path and return
    end

    def assign_current_appointment(appointment = nil)
      session[:appointment_token] = appointment.present? ? appointment.link_token : nil
      return nil unless appointment.present?
      @current_location = appointment.location
      @current_appointment = appointment
    end

    def permitted_create_params
      params.require(:appointment)
            .permit(:email, :name, :reason, :description)
            .merge(location_id: current_location.id, organization_id: current_organization.id)
    end
  end
end
