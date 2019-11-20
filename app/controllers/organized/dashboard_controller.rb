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
        @bikes_in_child_organizations_count = Bike.organization(@child_organizations.pluck(:id)).where(created_at: @time_range).count(:all)
        @bikes_in_nearby_organizations_count = Bike.organization(current_organization.nearby_organizations.pluck(:id)).where(created_at: @time_range).count(:all)
        @bikes_in_region_unaffiliated_count = current_organization.bikes_nearby_unorganized.where(created_at: @time_range).count(:all)
        # @unaffiliated_regional_organizations = current_organization
        # @regional_bike_counts = {}.tap do |cts|
        #   cts[:bikes_in_organizations_count] =
        #     current_organization.bikes_in_nearby_organizations.count(:all)
        #   cts[:bikes_in_region_unaffiliated_count] =
        #     current_organization.bikes_nearby_unaffiliated.count(:all)
        #   cts[:bikes_in_region_count] =
        #     current_organization.bikes_nearby.count(:all)
        #   cts[:organizations_nearby] =
        #     current_organization
        #       .organizations_nearby
        #       .includes(:bikes)
        #       .group("organizations.id, organizations.name")
        #       .count(:bikes)
      end
    end

    def set_default_period
      @period = "year" unless params[:period].present?
    end
  end
end
