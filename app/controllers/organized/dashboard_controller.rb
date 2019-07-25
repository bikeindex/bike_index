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
    end
  end
end
