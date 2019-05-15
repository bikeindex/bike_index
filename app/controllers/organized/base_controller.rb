module Organized
  class BaseController < ApplicationController
    before_filter :ensure_current_organization!
    before_filter :ensure_member!
    layout "application_revised"

    def index
      if current_organization.ambassador?
        redirect_to organization_ambassador_dashboard_index_path
      else
        redirect_to organization_bikes_path
      end
    end

    def ensure_member!
      return true if current_user && current_user.member_of?(current_organization)
      set_passive_organization(nil) # remove the active organization, because it failed so don't show it anymore
      flash[:error] = "You're not a member of that organization!"
      redirect_to user_home_url(subdomain: false) and return
    end

    def ensure_admin!
      return true if current_user && current_user.admin_of?(current_organization)
      flash[:error] = "You have to be an organization administrator to do that!"
      redirect_to organization_bikes_path(organization_id: current_organization.to_param) and return
    end

    def ensure_ambassador_or_superuser!
      return true if current_user && current_user.superuser? || current_user.ambassador?
      flash[:error] = "You have to be an ambassador to do that!"
      redirect_to user_root_url
    end

    def ensure_current_organization!
      return true if current_organization.present?
      fail ActiveRecord::RecordNotFound
    end
  end
end
