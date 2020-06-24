module Organized
  class AppointmentConfigurationsController < Organized::AdminController
    before_action :ensure_access_to_appointments!
    before_action :find_appointment_configuration, except: [:index]

    def index
      if current_organization.locations.count == 1
        redirect_to edit_organization_appointment_configuration_path(current_organization.locations.first.to_param,
                                                                     organization_id: current_organization.to_param) and return
      end
    end

    def edit
    end

    def update
      if @appointment_configuration.update(permitted_parameters)
        flash[:success] = "Appointments Configuration updated"
        redirect_back(fallback_location: organization_root_url)
      else
        flash[:error] = @appointment_configuration.errors.full_messages.to_sentence
        render :edit
      end
    end

    private

    def ensure_access_to_appointments!
      # ensure_admin! passes with superuser - this allow superuser to see even if org not enabled
      return true if current_user.superuser? || current_organization.appointment_functionality_enabled?

      flash[:error] = translation(:org_does_not_have_access)
      redirect_to organization_root_path and return
    end

    def find_appointment_configuration
      @location = current_organization.locations.friendly_find(params[:id])
      fail ActiveRecord::RecordNotFound unless @location.present?
      @appointment_configuration = @location.appointment_configuration
      return @appointment_configuration if @appointment_configuration.present?
      @appointment_configuration = AppointmentConfiguration.new(organization_id: current_organization.id,
                                                                location_id: @location.id,
                                                                reasons: AppointmentConfiguration.default_reasons)
    end

    def permitted_parameters
      params.require(:appointment_configuration).permit([:virtual_line_on, :reasons_text])
    end
  end
end
