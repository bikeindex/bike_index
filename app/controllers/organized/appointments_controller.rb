module Organized
  class AppointmentsController < Organized::BaseController
    before_action :find_appointment, except: [:create]

    def update
      if params[:status].present?
        appointment_update = @appointment.record_status_update(new_status: params[:status],
                                                               updator_id: current_user.id,
                                                               updator_kind: "organization_member")
        if appointment_update.present?
          flash[:success] = "Appointment updated: #{params[:status].humanize}"
        else
          flash[:error] = "Unable to update that appointment!"
        end
      end
      redirect_back_to_organized_line
    end

    def create
      @appointment = Appointment.new(permitted_create_params)
      @appointment.status ||= "waiting"
      if @appointment.save
        flash[:success] = "Added #{@appointment.name} to line!"
      else
        flash[:error] = @appointment.errors.full_messages.to_sentence
      end
      redirect_back_to_organized_line
    end

    private

    def redirect_back_to_organized_line
      redirect_back(fallback_location: organization_line_path(@appointment.location.to_param, organization_id: current_organization.to_param))
    end

    def find_appointment
      @appointment = current_organization.appointments.find(params[:id])
    end

    def permitted_create_params
      params.require(:appointment)
        .permit(:email, :name, :reason, :description, :location_id, :status)
        .merge(organization_id: current_organization.id, user_id: current_user.id, creator_kind: "organization_member")
    end
  end
end
