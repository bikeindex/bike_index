class Admin::PaintsController < Admin::BaseController
  before_filter :find_paint, only: [:show, :edit, :update, :destroy]

  def index
    if params[:name]
      paints = Paint.where('name LIKE ?', "%#{params[:name]}%")
    else 
      paints = Paint.order("bikes_count DESC")
    end
    @paints = paints.includes(:color, :secondary_color, :tertiary_color).paginate(page: params[:page]).per_page(100)
  end

  # def new
  # end

  # def create
  # end

  def show
    redirect_to edit_admin_paint_url(@paint)
  end

  def edit
    @bikes = @paint.bikes.includes(:cycle_type, :paint, :manufacturer, :creation_organization)
  end

  def update
    if @paint.update_attributes(params[:paint])
      black_id = Color.find_by_name('Black').id
      flash[:notice] = "Paint updated!"
      if @paint.reload.color_id.present?
        bikes = @paint.bikes.where(primary_frame_color_id: black_id)
        bikes.each do |bike|
          next if bike.secondary_frame_color_id.present?
          next unless bike.primary_frame_color_id == black_id
          bike.primary_frame_color_id = @paint.color_id
          bike.secondary_frame_color_id = @paint.secondary_color_id
          bike.tertiary_frame_color_id = @paint.tertiary_color_id
          bike.paint_name = @paint.name
          bike.save
        end
      end
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
      flash[:notice] = "Paint deleted!"
    end
    redirect_to admin_paints_url
  end

  protected

  def find_paint
    @paint = Paint.find(params[:id])
  end
end
