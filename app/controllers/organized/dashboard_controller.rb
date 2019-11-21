module Organized
  class DashboardController < Organized::BaseController
    before_action :set_default_period
    before_action :set_period, only: [:index]

    def root
      if current_organization.ambassador?
        redirect_to organization_ambassador_dashboard_path
      else
        redirect_to organization_bikes_path
      end
    end

    def index
      @child_organizations = current_organization.child_organizations
      if current_organization.regional?
        @nearby_organizations = current_organization.nearby_organizations
        @affiliated_organization_ids = current_organization.nearby_organizations.pluck(:id) + @child_organizations.pluck(:id)
        @bikes_in_child_organizations_count = Bike.organization(@child_organizations.pluck(:id)).where(created_at: @time_range).count(:all)
        @bikes_in_nearby_organizations_count = Bike.organization(current_organization.nearby_organizations.pluck(:id)).where(created_at: @time_range).count(:all)
        @bikes_in_region_unaffiliated_count = current_organization.bikes_nearby_unorganized.where(created_at: @time_range).count(:all)
      end
    end

    def set_default_period
      @period = "year" unless params[:period].present?
    end
  end
end
