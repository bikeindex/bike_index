module Organized
  class StickersController < Organized::BaseController
    before_action :ensure_access_to_bike_codes!, except: [:create] # Because this checks ensure_admin
    before_action :find_bike_code, only: [:edit, :update]

    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @bike_codes = searched.includes(:bike).order(created_at: :desc).page(@page).per(@per_page)
    end

    def edit
    end

    # This is exactly the same as bike_codes_controller update - except the redirect is different
    def update
      if !@bike_code.claimable_by?(current_user)
        flash[:error] = "You can't update that #{@bike_code.kind}. Please contact support@bikeindex.org if you think you should be able to"
      else
        bike_id = params[:bike_id].present? ? params[:bike_id] : params.dig(:bike_code, :bike_id)
        @bike_code.claim(current_user, bike_id)
        if @bike_code.errors.any?
          flash[:error] = @bike_code.errors.full_messages.to_sentence
        else
          flash[:success] = "#{@bike_code.kind.titleize} #{@bike_code.claimed? ? "claimed" : "unclaimed"}"
          redirect_to organization_stickers_path(organization_id: current_organization.to_param) and return
        end
      end
      redirect_to edit_organization_sticker_path(organization_id: current_organization.to_param, id: @bike_code.code)
    end

    private

    def find_bike_code
      @bike_code = bike_codes.lookup(params[:id])
      unless @bike_code.present?
        flash[:error] = "Unable to find that sticker"
        redirect_to organization_stickers_path(organization_id: current_organization.to_param) and return
      end
    end

    def bike_codes
      BikeCode.where(organization_id: current_organization.id)
    end

    def searched
      searched_codes = bike_codes
      if params[:bike_query].present?
        searched_codes = searched_codes.claimed.where(bike_id: Bike.friendly_find(params[:bike_query])&.id)
      elsif params[:claimedness] && params[:claimedness] != "all"
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
