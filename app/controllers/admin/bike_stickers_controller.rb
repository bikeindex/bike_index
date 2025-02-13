class Admin::BikeStickersController < Admin::BaseController
  include SortableTable
  

  def index
    @pagy, @bike_stickers = scoped_bike_stickers(matching_bike_stickers)

    @bike_sticker_batches = if @bike_sticker_batch.present?
      [@bike_sticker_batch]
    elsif @matching_batches
      BikeStickerBatch.where(id: @bike_stickers.reorder(:bike_sticker_batch_id).distinct.pluck(:bike_sticker_batch_id))
        .reorder(id: :desc)
        .includes(:organization)
    else
      @all_batches = InputNormalizer.boolean(params[:search_all_batches])
      batches = BikeStickerBatch.reorder(id: :desc).includes(:organization)
      @all_batches ? batches : batches.limit(5)
    end
  end

  def new
    @bike_sticker_batch ||= BikeStickerBatch.new
    @bike_sticker_batch.organization ||= current_organization
    @bike_sticker_batch.initial_code_integer ||= 1
    @organizations = Organization.all
  end

  def create
    create_batch_if_valid!
    if @bike_sticker_batch.id.present?
      flash[:success] = "Batch ##{@bike_sticker_batch.id} created. Please wait a few minutes for the stickers to finish creating"
      CreateBikeStickerCodesJob.perform_async(@bike_sticker_batch.id,
        @bike_sticker_batch.stickers_to_create_count, @bike_sticker_batch.initial_code_integer)
      redirect_to admin_bike_stickers_path(search_bike_sticker_batch_id: @bike_sticker_batch.id)
    else
      @organizations = Organization.all
      render :new
    end
  end

  def reassign
    @pagy, @bike_stickers = scoped_bike_stickers(selected_bike_stickers)
    # Check that the selection matches our criteria
    @valid_selection = @bike_sticker1.present? &&
      selected_bike_stickers.count > 0 &&
      selected_bike_stickers.count <= max_reassign_size &&
      params[:organization_id].present? &&
      params[:search_bike_sticker_batch_id].present?
    # update if possible
    if @valid_selection && InputNormalizer.boolean(params[:reassign_now])
      AdminReassignBikeStickerCodesJob.perform_async(current_user.id,
        current_organization.id,
        @bike_sticker_batch.id,
        @bike_sticker1&.id,
        @bike_sticker2&.id)
      flash[:success] = "Reassigning organization! Please wait a few minutes for the stickers to finish updating"
      redirect_to admin_bike_stickers_path
      return
    end
    @bike_sticker_batches = if @bike_sticker_batch.present?
      [@bike_sticker_batch]
    else
      BikeStickerBatch.where(organization_id: 1).reorder(id: :desc)
    end
  end

  helper_method :matching_bike_stickers, :max_reassign_size, :selected_bike_stickers

  private

  def max_reassign_size
    1000
  end

  def sortable_columns
    %w[created_at updated_at claimed_at code_integer organization_id bike_sticker_batch_id]
  end

  def default_column
    (action_name == "reassign") ? "code_integer" : sortable_columns.first
  end

  def default_direction
    (action_name == "reassign") ? "asc" : "desc"
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
      bike_stickers = bike_stickers.sticker_code_search(params[:search_query])
    end
    @time_range_column = sort_column if %w[created_at updated_at claimed_at].include?(sort_column)
    @time_range_column ||= "created_at"
    @matching_bike_stickers = bike_stickers.where(@time_range_column => @time_range)
  end

  def selected_bike_stickers
    return @selected_bike_stickers if defined?(@selected_bike_stickers)
    bike_stickers = BikeSticker.all
    if params[:search_sticker1].present?
      @bike_sticker1 = bike_stickers.lookup(params[:search_sticker1])
      if @bike_sticker1.present?
        bike_stickers = bike_stickers.where("code_integer >= ?", @bike_sticker1.code_integer)
      end
    end
    if params[:search_sticker2].present?
      @bike_sticker2 = bike_stickers.lookup(params[:search_sticker2])
      if @bike_sticker2.present?
        bike_stickers = bike_stickers.where("code_integer <= ?", @bike_sticker2.code_integer)
      end
    end
    # Assign batch based on passed sticker id or  the first sticker found
    if params[:search_bike_sticker_batch_id].present?
      @bike_sticker_batch = BikeStickerBatch.find(params[:search_bike_sticker_batch_id])
    elsif @bike_sticker_batch.blank? && (@bike_sticker1.present? || @bike_sticker2.present?)
      @bike_sticker_batch = @bike_sticker1&.bike_sticker_batch || @bike_sticker2&.bike_sticker_batch
    end

    bike_stickers = bike_stickers.where(bike_sticker_batch_id: @bike_sticker_batch.id) if @bike_sticker_batch.present?
    @selected_bike_stickers = bike_stickers
  end

  def scoped_bike_stickers(stickers)
    @per_page = params[:per_page] || 25
    pagy(stickers.reorder("bike_stickers.#{sort_column} #{sort_direction}")
      .includes(:organization, :bike_sticker_batch, :bike_sticker_updates, :bike), limit: @per_page)
  end

  def permitted_parameters
    params.require(:bike_sticker_batch)
      .permit(:notes, :prefix, :initial_code_integer, :stickers_to_create_count,
        :organization_id, :code_number_length)
      .merge(user_id: current_user.id)
  end

  def create_batch_if_valid!
    @bike_sticker_batch = BikeStickerBatch.new(permitted_parameters)
    @bike_sticker_batch.validate
    unless @bike_sticker_batch.stickers_to_create_count.to_i > 0
      @bike_sticker_batch.errors.add(:base, "Number of stickers to create is required")
    end
    if @bike_sticker_batch.organization_id.blank?
      @bike_sticker_batch.errors.add(:organization_id, "Organization required")
    end

    if @bike_sticker_batch.prefix.blank?
      @bike_sticker_batch.errors.add(:prefix, "Prefix is required")
    else
      overlapping_batches = BikeStickerBatch.where(prefix: @bike_sticker_batch.prefix).select do |batch|
        @bike_sticker_batch.initial_code_integer.between?(batch.min_code_integer, batch.max_code_integer)
      end
      overlapping_batches.each { |b| @bike_sticker_batch.errors.add(:base, "Existing sticker batch ##{b.id} has overlapping codes") }
    end

    @bike_sticker_batch.save unless @bike_sticker_batch.errors.any?
    @bike_sticker_batch
  end
end
