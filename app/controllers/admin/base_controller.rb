class Admin::BaseController < ApplicationController
  before_action :require_index_admin!
  layout "admin"
  before_action :assign_default_per_page

  def assign_default_per_page
    @per_page = 25 # Lazy hack
  end

  # Permit viewing deleted organizations
  def current_organization
    return @current_organization if defined?(@current_organization)
    return @current_organization = nil if params[:organization_id] == "none" # manual nil organization setting
    @current_organization = Organization.unscoped.friendly_find(params[:organization_id])
    set_passive_organization(@current_organization)
  end
end
