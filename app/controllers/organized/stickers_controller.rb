module Organized
  class StickersController < Organized::BaseController
    before_action :ensure_access_to_bike_codes!, except: [:create] # Because this checks ensure_admin
    before_action :find_bike_code, only: [:edit, :update]

    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @bike_codes = searched.order(created_at: :desc).page(@page).per(@per_page)
    end

    def edit
    end

    private

    def find_bike_code
      @bike_code = bike_codes.lookup(params[:id])
    end

    def bike_codes
      BikeCode.where(organization_id: current_organization.id)
    end

    def searched
      searched_codes = bike_codes
      if params[:claimedness] && params[:claimedness] != "all"
        searched_codes = params[:claimedness] == "claimed" ? searched_codes.claimed : searched_codes.unclaimed
      end
      searched_codes.admin_text_search(params[:query])
    end

    def ensure_access_to_bike_codes!
      return true if current_organization.has_bike_codes || current_user.superuser?
      flash[:error] = "Your organization doesn't have access to that, please contact Bike Index support"
      redirect_to organization_bikes_path(organization_id: current_organization.to_param) and return
    end
  end
end
