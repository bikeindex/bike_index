module OrgPublic
  class CustomerAppointmentsController < OrgPublic::BaseController
    # If a user has a link to an appointment, render it - even if the org no longer has the functionality enabled
    before_action :find_appointment_and_redirect, only: [:show, :set_current]

    layout "customer_virtual_line"

    def show; end

    def set_current; end

    def create
      @appointment = Appointment.new(permitted_create_params)
      if @appointment.save
        flash[:success] = "You're now in line!"
        assign_current_appointment(@appointment)
      else
        flash[:error] = @appointment.errors.full_messages.to_sentence
      end
      redirect_to walkrightup_route and return
    end

    def update
      @appointment = current_organization.appointments.find_by_link_token(params[:token])
      @appointment.update(permitted_update_params)
      redirect_to walkrightup_route
    end

    private

    def walkrightup_route
      organization_walkrightup_path(organization_id: current_organization.to_param,
                                    location_id: current_appointment&.location&.to_param)
    end

    def find_appointment_and_redirect
      @token = params[:token] || params[:id]
      @appointment ||= current_organization.appointments.find_by_link_token(@token)
      if @appointment.present?
        # Only assign if the appointment is present, so we don't lose the existing one
        assign_current_appointment(@appointment)
      else
        flash[:error] = "Unable to find that appointment!"
        current_appointment # Grab it if it's around, because at least something
      end
      redirect_to walkrightup_route and return
    end

    def assign_current_appointment(appointment = nil)
      session[:appointment_token] = appointment.present? ? appointment.link_token : nil
      return nil unless appointment.present?
      @current_location = appointment.location
      @current_appointment = appointment
    end

    def permitted_create_params
      params.require(:appointment)
        .permit(:email, :name, :reason, :description, :location_id)
        .merge(organization_id: current_organization.id, status: "waiting")
    end
  end
end
