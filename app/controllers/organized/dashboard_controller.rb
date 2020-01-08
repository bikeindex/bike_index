module Organized
  class DashboardController < Organized::BaseController
    before_action :set_default_period
    before_action :set_period, only: [:index]
    helper_method :bikes_for_graph

    def root
      if current_organization.ambassador?
        redirect_to organization_ambassador_dashboard_path
      else
        redirect_to organization_bikes_path
      end
    end

    def index
      @period = "week" unless params[:period].present?
      @child_organizations = current_organization.child_organizations
      if current_organization.regional?
        @bikes_in_organizations = Bike.unscoped.current.organization(current_organization.nearby_and_partner_organization_ids).where(created_at: @time_range)
        @bikes_not_in_organizations = current_organization.bikes_nearby.where.not(id: @bikes_in_organizations.pluck(:id)).where(created_at: @time_range)

        @bikes_in_organization_count = current_organization.bikes.where(created_at: @time_range).count
        @bikes_in_child_organizations_count = Bike.organization(@child_organizations.pluck(:id)).where(created_at: @time_range).count
        @bikes_in_nearby_organizations_count = Bike.organization(current_organization.nearby_organizations.pluck(:id)).where(created_at: @time_range).count
        @bikes_in_region_not_in_organizations_count = @bikes_not_in_organizations.count
      end
    end

    private

    def set_default_period
      @period = "year" unless params[:period].present?
    end
  end
end
