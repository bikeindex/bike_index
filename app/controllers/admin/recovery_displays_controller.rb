class Admin::RecoveryDisplaysController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]
  before_action :find_recovery_displays, only: [:edit, :update, :destroy]

  helper_method :matching_recovery_displays

  def index
    page = params[:page] || 1
    @per_page = params[:per_page] || 50
    @recovery_displays = matching_recovery_displays.page(page).per(@per_page)
      .order(@time_range_column => sort_direction)
  end

  def new
    @recovery_display = RecoveryDisplay.new
    if params[:stolen_record_id].present?
      @recovery_display.from_stolen_record(params[:stolen_record_id])
      @stolen_record = @recovery_display.stolen_record
      @bike = @recovery_display.bike
    end
  end

  def show
    if params[:id] == "bust_cache"
      flash[:success] = "Recovery Display Cache busted"
      redirect_to admin_recovery_displays_path
    else
      redirect_to edit_admin_recovery_display_url
    end
  end

  def edit
    @stolen_record = @recovery_display.stolen_record
    @bike = @recovery_display.bike
  end

  def update
    if @recovery_display.update(permitted_parameters)
      flash[:success] = "Recovery display saved!"
      redirect_to admin_recovery_displays_path
    else
      render action: :edit
    end
  end

  def create
    @recovery_display = RecoveryDisplay.create(permitted_parameters)
    if @recovery_display.save
      flash[:success] = "Recovery display created!"
      redirect_to admin_recoveries_path
    else
      render action: :new
    end
  end

  def destroy
    @recovery_display.destroy
    redirect_to admin_recovery_displays_path
  end

  protected

  def sortable_columns
    %w[recovered_at created_at updated_at]
  end

  def permitted_parameters
    params.require(:recovery_display)
      .permit(:stolen_record_id, :quote, :quote_by, :recovered_at, :link, :image,
        :remote_image_url, :date_input, :remove_image)
  end

  def find_recovery_displays
    @recovery_display = RecoveryDisplay.find(params[:id])
    raise ActionController::RoutingError.new("Not Found") unless @recovery_display.present?
  end

  def earliest_period_date
    Time.at(1412748000)
  end

  def matching_recovery_displays
    recovery_displays = RecoveryDisplay.unscoped
    if params[:search_bike_id].present?
      @bike = Bike.unscoped.friendly_find(params[:search_bike_id])
      recovery_displays = recovery_displays.where(stolen_record_id: @bike.recovered_records.pluck(:id)) if @bike.present?
    end
    @time_range_column = sort_column if %w[created_at updated_at].include?(sort_column)
    @time_range_column ||= "recovered_at"
    recovery_displays.where(@time_range_column => @time_range)
  end
end
