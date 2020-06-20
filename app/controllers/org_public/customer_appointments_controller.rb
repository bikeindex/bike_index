module OrgPublic
  class CustomerAppointmentsController < OrgPublic::BaseController
    # If a user has a link to an appointment, render it - even if the org no longer has the functionality enabled
    before_action :ensure_access_to_virtual_line!, except: [:show]
    before_action :find_appointment, except: [:create]

    def show
    end

    def create
    end

    def update
    end

    private

    def find_appointment
      @appointment ||= current_organization.appointments.find_by_link_token(params[:id])
      if @appointment.present?
        @current_location = @appointment.location
        return @appointment
      end
      raise ActiveRecord::RecordNotFound
    end
  end
end
