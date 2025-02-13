class Admin::PaintsController < Admin::BaseController
  include SortableTable

  before_action :find_paint, only: [:show, :edit, :update, :destroy]

  def index
    @per_page = params[:per_page] || 100
    @pagy, @paints = pagy(matching_paints.reorder("paints.#{sort_column} #{sort_direction}")
      .includes(:color, :secondary_color, :tertiary_color), limit: @per_page)
  end

  def show
    redirect_to edit_admin_paint_url(@paint)
  end

  def edit
    @per_page = params[:per_page] || 20
    bikes = Bike.unscoped.default_includes.includes(:paint)
      .where(paint_id: @paint.id).order("created_at desc")
    @bikes_count = bikes.size
    @pagy, @bikes = pagy(bikes, limit: @per_page)
  end

  def update
    if @paint.update(permitted_parameters)
      UpdatePaintJob.perform_async(@paint.id)
      flash[:success] = "Paint updating!"
      redirect_to admin_paints_url
    else
      render action: :edit
    end
  end

  def destroy
    if @paint.bikes.present?
      flash[:error] = "Not allowed! Bikes use that paint! How the fuck did you delete that anyway?"
    else
      @paint.destroy
      flash[:success] = "Paint deleted!"
    end
    redirect_to admin_paints_url
  end

  helper_method :matching_paints

  protected

  def sortable_columns
    %w[created_at updated_at name bikes_count]
  end

  def earliest_period_date
    Time.at(1389138422) # Earliest sticker created_at
  end

  def permitted_parameters
    params.require(:paint).permit(:color_id, :manufacturer_id, :secondary_color_id, :tertiary_color_id, :bikes_count)
  end

  def find_paint
    @paint = Paint.find(params[:id])
  end

  def matching_paints
    paints = if params[:search_name]
      Paint.where("name LIKE ?", "%#{params[:search_name]}%")
    else
      Paint
    end
    @search_unlinked = InputNormalizer.boolean(params[:search_unlinked])
    paints = paints.unlinked if @search_unlinked
    paints.where(created_at: @time_range)
  end
end
