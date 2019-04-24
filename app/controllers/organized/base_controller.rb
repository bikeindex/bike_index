module Organized
  class BaseController < ApplicationController
    before_filter :ensure_active_organization!
    before_filter :ensure_member!
    layout "application_revised"

    def ensure_member!
      return true if current_user && current_user.member_of?(active_organization)
      set_current_organization(nil) # remove the active organization, because it failed so don't show it anymore
      flash[:error] = "You're not a member of that organization!"
      redirect_to user_home_url(subdomain: false) and return
    end

    def ensure_admin!
      return true if current_user && current_user.admin_of?(active_organization)
      flash[:error] = "You have to be an organization administrator to do that!"
      redirect_to organization_bikes_path(organization_id: active_organization.to_param) and return
    end

    def ensure_active_organization!
      return true if active_organization.present?
      fail ActiveRecord::RecordNotFound
    end
  end
end
