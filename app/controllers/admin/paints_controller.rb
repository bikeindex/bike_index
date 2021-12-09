class Admin::PaintsController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]
  before_action :find_paint, only: [:show, :edit, :update, :destroy]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 100
    @paints = matching_paints.reorder("paints.#{sort_column} #{sort_direction}")
      .includes(:color, :secondary_color, :tertiary_color)
      .page(page).per(per_page)
  end

  def show
    redirect_to edit_admin_paint_url(@paint)
  end

  def edit
    page = params[:page] || 1
    per_page = params[:per_page] || 20
    @bikes = Bike.unscoped.includes(:creation_organization, :creation_states, :paint)
      .where(paint_id: @paint.id).order("created_at desc")
      .page(page).per(per_page)
  end

  def update
    if @paint.update_attributes(permitted_parameters)
      black_id = Color.find_by_name("Black").id
      flash[:success] = "Paint updated!"
      UpdatePaintWorker.perform_async(@paint.id)
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
    @search_unlinked = ParamsNormalizer.boolean(params[:search_unlinked])
    paints = paints.unlinked if @search_unlinked
    paints.where(created_at: @time_range)
  end
end
