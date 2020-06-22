module OrgPublic
  class CustomerLinesController < OrgPublic::BaseController
    before_action :ensure_access_to_virtual_line!

    layout "customer_virtual_line"

    def show
      @appointments_in_line = current_location.appointments.in_line
      @appointment = current_appointment
      @appointment ||= Appointment.new(organization: current_organization, location: current_location)
    end
  end
end
