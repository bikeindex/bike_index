class Admin::BikeStickersController < Admin::BaseController
  include SortableTable

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    @bike_stickers =
      matching_bike_stickers
        .reorder("bike_stickers.#{sort_column} #{sort_direction}")
        .includes(:organization)
        .page(page)
        .per(per_page)
  end

  helper_method :matching_bike_stickers

  private

  def sortable_columns
    %w[created_at code_integer organization_id bike_sticker_batch_id]
  end

  def matching_bike_stickers
    bike_stickers = BikeSticker.all
    if params[:organization_id].present?
      bike_stickers = bike_stickers.where(organization_id: current_organization.id)
    end
    if params[:search_bike_code_batch_id].present?
      @bike_sticker_batch = BikeStickerBatch.find(params[:search_bike_code_batch_id].to_i)
      bike_stickers = bike_stickers.where(bike_sticker_batch_id: @bike_sticker_batch.id)
    end
    if params[:search_claimed].present?
      bike_stickers = bike_stickers.claimed
    end
    if params[:search_query].present?
      bike_stickers = bike_stickers.admin_text_search(params[:search_query])
    end
    bike_stickers
  end
end
