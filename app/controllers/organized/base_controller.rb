module Organized
  class BaseController < ApplicationController
    before_action :ensure_not_ambassador_organization!, except: :root
    before_action :ensure_current_organization!
    before_action :ensure_member!

    def ensure_member!
      if current_user && current_user.member_of?(current_organization)
        return true if current_user.accepted_vendor_terms_of_service?
        flash[:success] = translation(:accept_tos_for_orgs,
                                      scope: [:controllers, :organized, :base, __method__])
        redirect_to accept_vendor_terms_path and return
      end
      set_passive_organization(nil) # remove the active organization, because it failed so don't show it anymore
      flash[:error] = translation(:not_a_member_of_that_org,
                                  scope: [:controllers, :organized, :base, __method__])
      redirect_to user_root_url and return
    end

    def ensure_admin!
      return true if current_user && current_user.admin_of?(current_organization)
      flash[:error] = translation(:must_be_org_admin,
                                  scope: [:controllers, :organized, :base, __method__])
      redirect_to organization_root_path and return
    end

    def ensure_ambassador_authorized!
      if current_organization&.ambassador?
        return true if current_user && current_user.superuser? || current_user.ambassador?
        flash[:error] = translation(:must_be_ambassador,
                                    scope: [:controllers, :organized, :base, __method__])
      else
        flash[:error] = translation(:must_be_in_ambassador_org,
                                    scope: [:controllers, :organized, :base, __method__])
      end
      redirect_to user_root_url
    end

    def ensure_not_ambassador_organization!
      return true unless current_organization&.ambassador?
      flash[:error] = translation(:must_be_an_admin,
                                  scope: [:controllers, :organized, :base, __method__])
      redirect_to organization_root_path and return
    end

    def ensure_current_organization!
      return true if current_organization.present?
      fail ActiveRecord::RecordNotFound
    end

    def ensure_appointments_enabled!
      if current_organization.enabled?("appointments")
        return true if current_organization_location.present?
        flash[:error] = "Organization must have a location to enable appointments"
        redirect_to locations_organization_manage_path and return
      else
        flash[:error] = "Appointments are not enabled for this organization"
        redirect_to organization_root_path and return
      end
    end
  end
end
