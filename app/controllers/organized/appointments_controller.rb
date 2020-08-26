# TODO: Live update the index table
module Organized
  class AppointmentsController < Organized::BaseController
    include SortableTable
    before_action :set_period, only: [:index]
    before_action :ensure_access_to_appointments!

    # NOTE: This currently isn't linked from the application, and shouldn't be viewed by users normally
    # ... keeping it in here because it's built and will be necessary eventually
    # ALSO - we need to live update this eventually
    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @appointments = matching_appointments.includes(:appointment_updates)
        .reorder("appointments.#{sort_column} #{sort_direction}")
        .page(@page).per(@per_page)
      @appointment ||= Appointment.new(location_id: current_location&.id, organization_id: current_organization.id)
    end

    def update
      if params[:status].present?
        if params[:id] == "multi_update"
          multi_appointment_update(params[:ids]&.keys || [])
        else
          find_appointment
          appointment_update = @appointment.record_status_update(new_status: params[:status],
                                                                 updator_id: current_user.id,
                                                                 updator_kind: "organization_member")
          if appointment_update.present?
            flash[:success] = "Appointment updated: #{appointment_update.status_humanized}"
          else
            flash[:error] = "Unable to update that appointment: #{@appointment.errors.full_messages.to_sentence}"
          end
        end
      end
      redirect_back(fallback_location: organization_appointments_path(organization_id: current_organization.to_param))
    end

    def create
      @appointment = Appointment.new(permitted_create_params)
      @appointment.status ||= "waiting"
      if @appointment.save
        flash[:success] = "Added #{@appointment.name} to line!"
      else
        flash[:error] = @appointment.errors.full_messages.to_sentence
      end
      redirect_back(fallback_location: organization_appointments_path(organization_id: current_organization.to_param))
    end

    helper_method :matching_appointments

    private

    def sortable_columns
      %w[created_at name status reason] # may use sometime: appointment_at line_number
    end

    def permitted_appointments
      current_organization.appointments
    end

    def matching_appointments
      matching_appointments = permitted_appointments
      matching_appointments = matching_appointments.where(location: current_location.id) if current_location.present?
      matching_appointments.where(created_at: @time_range)
    end

    def find_appointment
      @appointment = permitted_appointments.find(params[:id])
    end

    def permitted_create_params
      params.require(:appointment)
        .permit(:email, :name, :reason, :description, :location_id, :status)
        .merge(organization_id: current_organization.id, user_id: current_user.id, creator_kind: "organization_member")
    end

    def multi_appointment_update(checked_appointment_ids)
      if checked_appointment_ids
        permitted_appointments.where(id: checked_appointment_ids).each do |appointment|
          appointment.record_status_update(new_status: params[:status],
                                           updator_kind: "organization_member",
                                           updator_id: current_user.id)
        end
        flash[:success] = "Line updated successfully!"
      else
        flash[:notice] = "Nothing was updated! Did you check any boxes?"
      end
    end
  end
end
