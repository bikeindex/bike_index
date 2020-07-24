module Organized
  class BaseController < ApplicationController
    before_action :ensure_not_ambassador_organization!, except: :root
    before_action :ensure_current_organization!
    before_action :ensure_member!

    def ensure_member!
      ensure_member_of!(current_organization)
    end

    def ensure_admin!
      return true if current_user&.admin_of?(current_organization)
      return false unless ensure_member! # if this fails, we're already redirecting
      flash[:error] = translation(:must_be_org_admin,
        scope: [:controllers, :organized, :base, __method__])
      redirect_to(organization_root_path) && return
    end

    def ensure_ambassador_authorized!
      if current_organization&.ambassador?
        return true if current_user&.superuser? || current_user&.ambassador?
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
      redirect_to(organization_root_path) && return
    end

    def ensure_access_to_appointments!
      # ensure_admin! passes with superuser - this allow superuser to see even if org not enabled
      return true if current_user.superuser? || current_organization.appointment_functionality_enabled?

      flash[:error] = translation(:org_does_not_have_access,
        scope: [:controllers, :organized, :base, __method__])
      redirect_to(organization_root_path) && return
    end
  end
end
