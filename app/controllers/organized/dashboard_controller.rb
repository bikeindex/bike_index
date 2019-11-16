module Organized
  class DashboardController < Organized::BaseController
    def root
      if current_organization.ambassador?
        redirect_to organization_ambassador_dashboard_path
      else
        redirect_to organization_bikes_path
      end
    end

    def index
      if current_organization.regional? && current_organization.is_paid?
        @regional_bike_counts = {}.tap do |cts|
          cts[:bikes_in_organizations_count] =
            current_organization.bikes_in_nearby_organizations.count(:all)
          cts[:bikes_in_region_unaffiliated_count] =
            current_organization.bikes_nearby_unaffiliated.count(:all)
          cts[:bikes_in_region_count] =
            current_organization.bikes_nearby.count(:all)
          cts[:organizations_nearby] =
            current_organization
              .organizations_nearby
              .includes(:bikes)
              .group("organizations.id, organizations.name")
              .count(:bikes)
        end
      end
    end
  end
end
