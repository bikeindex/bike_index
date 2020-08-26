# AppointmentsController#index HTML view shows the table. Includes all the appointments
module Organized
  class OperateLinesController < Organized::BaseController
    before_action :ensure_access_to_appointments!
    before_action :assign_current_location, except: [:index]

    def index
      if current_location.present?
        redirect_to(organization_operate_line_path(current_location.to_param, organization_id: current_organization.to_param)) && return
      end
    end

    def show
      @appointments = matching_appointments.includes(:appointment_updates)
      render layout: false
    end

    def update

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
  end
end
