module Organized
  class BaseController < ApplicationController
    before_filter :ensure_not_ambassador_organization!, except: :root
    before_filter :ensure_current_organization!
    before_filter :ensure_member!

    def ensure_member!
      if current_user && current_user.member_of?(current_organization)
        return true if current_user.accepted_vendor_terms_of_service?
        flash[:success] = "Please accept the terms of service for organizations"
        redirect_to accept_vendor_terms_path and return
      end
      set_passive_organization(nil) # remove the active organization, because it failed so don't show it anymore
      flash[:error] = "You're not a member of that organization!"
      redirect_to user_root_url and return
    end

    def ensure_admin!
      return true if current_user && current_user.admin_of?(current_organization)
      flash[:error] = "You have to be an organization administrator to do that!"
      redirect_to organization_root_path and return
    end

    def ensure_ambassador_authorized!
      if current_organization&.ambassador?
        return true if current_user && current_user.superuser? || current_user.ambassador?
        flash[:error] = "You have to be an ambassador to do that!"
      else
        flash[:error] = "You have to be in an ambassador organization to see that!"
      end
      redirect_to user_root_url
    end

    def ensure_not_ambassador_organization!
      return true unless current_organization&.ambassador?
      flash[:error] = "You have to be an admin to do that!"
      redirect_to organization_root_path
    end

    def ensure_current_organization!
      return true if current_organization.present?
      fail ActiveRecord::RecordNotFound
    end
  end
end
