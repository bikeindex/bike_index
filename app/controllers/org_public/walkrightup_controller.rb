module OrgPublic
  class WalkrightupController < OrgPublic::BaseController
    before_action :ensure_access_to_virtual_line!

    layout "walkrightup"

    def show
      @appointments_in_line = current_location.appointments.in_line
      @appointment = current_appointment
      # If the appointment isn't in line, update so they can create a new appointment
      if @appointment.present? && !@appointment.in_line?
        flash[:info] = "Your last appointment is no longer in line!"
        @appointment = nil
      end
      @appointment ||= Appointment.new(organization: current_organization,
                                       location: current_location,
                                       email: current_user&.email,
                                       name: current_user&.name)
    end
  end
end
