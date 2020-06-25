module Organized
  class LinesController < Organized::BaseController
    before_action :ensure_access_to_appointments!

    def index
      if current_location.present?
        redirect_to organization_line_path(current_location.to_param, organization_id: current_organization.to_param) and return
      end
    end

    def show
      @appointments = matching_appointments
      @appointment ||= Appointment.new(location_id: current_location.id, organization_id: current_organization.id)
    end

    def update
      fail "not implemented"
    end

    private

    def matching_appointments
      current_location.appointments.in_line
    end
  end
end
