module OrgPublic
  class BaseController < ApplicationController
    before_action :ensure_current_organization!

    helper_method :current_appointment

    def ensure_access_to_virtual_line!
      return true if current_location&.virtual_line_on?

      if current_location.blank?
        flash[:error] = translation(:unable_to_find_location, location_id: params[:location_id], org_name: current_organization.short_name,
                                                              scope: [:controllers, :org_public, :base, __method__])
      elsif current_user&.authorized?(current_organization)
        return true if current_organization.appointment_functionality_enabled?

        url_to_redirect_to = organization_root_path(organization_id: current_organization)
      elsif current_organization.appointment_functionality_enabled?
        flash[:error] = translation(:location_does_not_have_access, location_name: current_location.name, org_name: current_organization.short_name,
                                                                    scope: [:controllers, :org_public, :base, __method__])
      end

      flash[:error] ||= translation(:org_does_not_have_access, org_name: current_organization.short_name,
                                                               scope: [:controllers, :org_public, :base, __method__])

      redirect_to(url_to_redirect_to || user_root_url) and return
    end

    def current_appointment
      return @current_appointment if defined?(@current_appointment)
      @current_appointment = current_organization.appointments.find_by_link_token(session[:appointment_token])
      @current_location = @current_appointment.location if @current_appointment.present?
      @current_appointment
    end
  end
end
