module Organized
  class StickersController < Organized::BaseController
    include SortableTable

    before_action :ensure_access_to_bike_stickers! # Because this checks ensure_admin
    before_action :find_bike_sticker, only: %i[edit update]

    def index
      @per_page = permitted_per_page
      @pagy, @bike_stickers = pagy(searched.includes(:bike)
        .reorder("bike_stickers.#{sort_column} #{sort_direction}"), limit: @per_page, page: permitted_page)
    end

    def show
      redirect_to edit_organization_sticker_path(params[:id], organization_id: params[:organization_id])
    end

    def edit
    end

    # This is exactly the same as BikeStickersController#update - except the redirect is different
    def update
      bike_id = params[:bike_id].present? ? params[:bike_id] : params.dig(:bike_sticker, :bike_id)
      @bike_sticker.claim_if_permitted(user: current_user, bike: bike_id, organization: current_organization)
      if @bike_sticker.errors.any?
        flash[:error] = @bike_sticker.errors.full_messages.to_sentence
      else
        flash[:success] = "#{@bike_sticker.kind.titleize} #{@bike_sticker.code} - #{@bike_sticker.claimed? ? "claimed" : "unclaimed"}"
        if @bike_sticker.bike.present?
          redirect_to(bike_path(@bike_sticker.bike_id)) && return
        end
      end
      redirect_back(
        fallback_location: edit_organization_sticker_path(
          organization_id: current_organization.to_param,
          id: @bike_sticker.code
        )
      )
    end

    private

    def sortable_columns
      %w[created_at claimed_at code_integer]
    end

    def bike_sticker_code
      params.dig(:bike_sticker, :code) || params[:id]
    end

    def find_bike_sticker
      bike_sticker = BikeSticker.lookup_with_fallback(bike_sticker_code, organization_id: current_organization.id, user: current_user)
      # use the loosest lookup
      @bike_sticker = bike_sticker if bike_sticker.present?
      return @bike_sticker if @bike_sticker.present?

      flash[:error] = translation(:unable_to_find_sticker, bike_sticker: bike_sticker_code)
      redirect_to(organization_stickers_path(organization_id: current_organization.to_param)) && return
    end

    def searched
      searched_codes = current_organization.bike_stickers
      if params[:search_bike].present?
        searched_codes = searched_codes.claimed.where(bike_id: Bike.friendly_find(params[:search_bike])&.id)
      elsif params[:search_claimedness] && params[:search_claimedness] != "all"
        searched_codes = (params[:search_claimedness] == "claimed") ? searched_codes.claimed : searched_codes.unclaimed
      end
      searched_codes.sticker_code_search(params[:query])
    end

    def ensure_access_to_bike_stickers!
      return true if current_organization.enabled?("bike_stickers") || current_user.superuser?

      raise_do_not_have_access!
    end
  end
end
