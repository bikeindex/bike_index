module Organized
  class StickersController < Organized::BaseController
    before_action :ensure_access_to_bike_codes!, except: [:create] # Because this checks ensure_admin
    before_action :find_bike_code, only: [:edit, :update]
    rescue_from ActionController::RedirectBackError, with: :redirect_back # Gross. TODO: Rails 5 update

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
          flash[:success] = "#{@bike_code.kind.titleize} - #{@bike_code.code} #{@bike_code.claimed? ? 'claimed' : 'unclaimed'}"
          if @bike_code.bike.present?
            redirect_to bike_path(@bike_code.bike_id) and return
          end
        end
      end
      redirect_to :back
    end

    private

    def bike_code_code
      params.dig(:bike_code, :code) || params[:id]
    end

    def find_bike_code
      bike_code = BikeCode.lookup_with_fallback(bike_code_code, organization_id: active_organization.id, user: current_user)
      # use the loosest lookup, but only permit it if the user can claim that
      @bike_code = bike_code if bike_code.present? && bike_code.claimable_by?(current_user)
      return @bike_code if @bike_code.present?
      flash[:error] = "Unable to find sticker with code: #{bike_code_code}"
      redirect_to organization_stickers_path(organization_id: active_organization.to_param) and return
    end

    def bike_codes
      BikeCode.where(organization_id: active_organization.id)
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
      return true if active_organization.paid_for?("bike_codes") || current_user.superuser?
      flash[:error] = "Your organization doesn't have access to that, please contact Bike Index support"
      redirect_to organization_bikes_path(organization_id: active_organization.to_param) and return
    end

    def redirect_back
      redirect_back_path = @bike_code.present? ? edit_organization_sticker_path(organization_id: active_organization.to_param, id: @bike_code.code) : organization_stickers_path(organization_id: params[:organization_id])
      redirect_to redirect_back_path
      return
    end
  end
end
