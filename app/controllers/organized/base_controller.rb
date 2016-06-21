module Organized
  class BaseController < ApplicationController
    before_filter :ensure_current_organization!
    before_filter :ensure_member!
    layout 'application_revised'

    def current_organization
      @current_organization ||= Organization.friendly_find(params[:organization_id])
    end

    def ensure_member!
      return true if current_user && current_user.is_member_of?(current_organization)
      flash[:error] = "You're not a member of that organization!"
      redirect_to user_home_url(subdomain: false) and return
    end

    def ensure_admin!
      return true if current_user && current_user.is_admin_of?(current_organization)
      flash[:error] = 'You have to be an organization administrator to do that!'
      redirect_to organization_bikes_path(organization_id: current_organization.to_param) and return
    end

    private

    def ensure_current_organization!
      fail ActiveRecord::RecordNotFound unless current_organization.present?
    end
  end
end
