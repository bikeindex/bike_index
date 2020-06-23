module OrgPublic
  class WalkrightupController < OrgPublic::BaseController
    before_action :ensure_access_to_virtual_line!

    layout "walkrightup"

    def show
      @appointments_in_line = current_location.appointments.in_line
      @appointment = current_appointment
      @appointment ||= Appointment.new(organization: current_organization, location: current_location)
    end
  end
end
