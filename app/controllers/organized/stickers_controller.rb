module Organized
  class StickersController < Organized::BaseController
    skip_before_filter :ensure_member!
    before_action :ensure_access_to_bike_codes!, except: [:create] # Because this checks ensure_admin

    def index
      @bike_codes = bike_codes.order(created_at: :desc)
    end

    helper_method :bike_codes

    private

    def ensure_access_to_bike_codes!
      return true if current_organization.has_bike_codes
      flash[:error] = "Your organization doesn't have access to that, please contact Bike Index support"
      redirect_to organization_bikes_path(organization_id: current_organization.to_param) and return
    end

    def bike_codes
      BikeCode.where(organization_id: current_organization.id)
    end
  end
end
