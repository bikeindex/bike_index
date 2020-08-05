class Admin::BikeStickerUpdatesController < Admin::BaseController
  include SortableTable

  before_action :set_period, only: [:index]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    @bike_sticker_updates =
      matching_bike_sticker_updates
        .reorder("bike_sticker_updates.#{sort_column} #{sort_direction}")
        .includes(:organization, :user, :bike)
        .page(page)
        .per(per_page)
  end

  helper_method :matching_bike_sticker_updates

  private

  def sortable_columns
    %w[created_at updated_at kind creator_kind organization_kind organization_id user_id]
  end

  def matching_bike_sticker_updates
    bike_sticker_updates = BikeStickerUpdate.all
    bike_stickers = BikeSticker.all
    if current_organization.present?
      bike_sticker_updates = bike_sticker_updates.where(organization_id: current_organization.id)
      bike_stickers = bike_stickers.where(organization_id: current_organization.id)
    end
    if params[:search_kind].present? && BikeStickerUpdate.kinds.include?(params[:search_kind])
      @search_kind = params[:search_kind]
      bike_sticker_updates = bike_sticker_updates.where(kind: @search_kind)
    else
      @search_kind = "all"
    end

    if params[:search_bike_sticker_id].present?
      @searched_bike_stickers = BikeSticker.where(id: id)
      bike_sticker_updates = bike_sticker_updates.where(id: @searched_bike_stickers.pluck(:bike_sticker_id))
    elsif params[:search_query].present?
      @searched_bike_stickers = bike_stickers.admin_text_search(params[:search_query])
      bike_sticker_updates = bike_sticker_updates.where(id: @searched_bike_stickers.pluck(:bike_sticker_id))
    end
    bike_sticker_updates.where(created_at: @time_range)
  end
end
