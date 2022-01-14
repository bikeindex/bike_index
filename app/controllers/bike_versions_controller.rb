class BikeVersionsController < ApplicationController
  before_action :render_ad, only: %i[index show]
  before_action :find_bike_version, except: %i[index new create]
  before_action :ensure_user_allowed_to_edit, except: %i[index show new create]

  def index
  end

  def show
    @page_title = @bike_version.display_name
  end

  def create
    bike = Bike.unscoped.find(params[:bike_id])
    if bike&.authorized?(current_user)
      # Do it inline because it's blocking
      bike_version = BikeVersionCreatorWorker.new.perform(bike.id)
      flash[:success] = "Bike Version created!"
      redirect_to edit_bike_version_path(bike_version.id)
    else
      flash[:error] = "You don't have permission to create a new version of that bike!"
      redirect_back(fallback_location: user_root_url)
    end
  end

  def update
    if @bike_version.update(permitted_params)
      flash[:success] = "#{@bike.type.titleize} version updated"
      redirect_to(edit_bike_version_path(@bike_version, edit_template: params[:edit_template])) && return
    else
      @edit_template = nil
      flash[:error] = "Unable to update"
      render :edit_template
    end
  end

  def destroy
    if @bike_version.destroy
      flash[:success] = "#{@bike_og.type.titleize} removed"
      redirect_to(edit_bike_path(@bike_og))
    else
      flash[:error] = "Unable to delete #{@bike.type}"
      redirect_back(fallback_location: edit_bike_version_path(@bike_version, edit_template: @edit_template))
    end
  end

  protected

  def find_bike_version
    begin
      @bike_version = BikeVersion.unscoped.find(params[:id])
    rescue ActiveRecord::StatementInvalid => e
      raise e.to_s.match?(/PG..NumericValueOutOfRange/) ? ActiveRecord::RecordNotFound : e
    end
    @bike = @bike_version
    @bike_og = @bike_version.bike
    return @bike_version if @bike_version.visible_by?(current_user)
    fail ActiveRecord::RecordNotFound
  end

  def ensure_user_allowed_to_edit
    return true if @bike_version.authorized?(current_user)
    flash[:error] = "You don't appear to own that bike version"
    redirect_to(bike_version_path(@bike_version)) && return
  end

  def render_ad
    @ad = true
  end

  # Sometimes this is bike_version:{}, other times it's bike:{} and I don't know why
  # I'm not super worried about it, so ignoring
  def permitted_params
    if params[:bike_version].present?
      params.require(:bike_version)
    else
      params.require(:bike)
    end.permit(:name,
      :description,
      :primary_frame_color_id,
      :secondary_frame_color_id,
      :tertiary_frame_color_id,
      :front_wheel_size_id,
      :rear_wheel_size_id,
      :rear_gear_type_id,
      :front_gear_type_id,
      :front_tire_narrow,
      :handlebar_type,
      :visibility,
      :start_at,
      :end_at,
      components_attributes: Component.permitted_attributes)
  end
end
