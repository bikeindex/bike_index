class Admin::BikeStickersController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    @bike_stickers =
      matching_bike_stickers
        .reorder("bike_stickers.#{sort_column} #{sort_direction}")
        .includes(:organization)
        .page(page)
        .per(per_page)
    @bike_sticker_batches = if @bike_sticker_batch.present?
      [@bike_sticker_batch]
    elsif @matching_batches
      BikeStickerBatch.where(id: @bike_stickers.reorder(:bike_sticker_batch_id).distinct.pluck(:bike_sticker_batch_id))
        .reorder(id: :desc)
    else
      @all_batches = ParamsNormalizer.boolean(params[:search_all_batches])
      batches = BikeStickerBatch.reorder(id: :desc)
      @all_batches ? batches : batches.limit(5)
    end
  end

  def new
    @bike_sticker_batch ||= BikeStickerBatch.new
    @bike_sticker_batch.organization ||= current_organization
    @bike_sticker_batch.initial_code_integer ||= 0
    @bike_sticker_batch.stickers_to_create_count ||= 0
    @organizations = Organization.all
  end

  helper_method :matching_bike_stickers

  private

  def sortable_columns
    %w[created_at updated_at claimed_at code_integer organization_id bike_sticker_batch_id]
  end

  def matching_bike_stickers
    return @matching_bike_stickers if defined?(@matching_bike_stickers)
    bike_stickers = BikeSticker.all
    if current_organization.present?
      @matching_batches = true
      bike_stickers = bike_stickers.where(organization_id: current_organization.id)
    end
    if params[:search_bike_sticker_batch_id].present?
      @bike_sticker_batch = BikeStickerBatch.find(params[:search_bike_sticker_batch_id].to_i)
      bike_stickers = bike_stickers.where(bike_sticker_batch_id: @bike_sticker_batch.id)
    end
    if params[:search_claimed].present? || sort_column == "claimed_at"
      @search_claimed = true
      @matching_batches = true
      bike_stickers = bike_stickers.claimed
    end
    if params[:search_query].present?
      @matching_batches = true
      bike_stickers = bike_stickers.admin_text_search(params[:search_query])
    end
    @time_range_column = sort_column if %w[created_at updated_at claimed_at].include?(sort_column)
    @time_range_column ||= "created_at"
    @matching_bike_stickers = bike_stickers.where(@time_range_column => @time_range)
  end
end
