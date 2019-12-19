class Admin::RecoveryDisplaysController < Admin::BaseController
  before_action :find_recovery_displays, only: [:edit, :update, :destroy]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @recovery_displays = RecoveryDisplay.order(created_at: :desc).page(page).per(per_page)
  end

  def new
    @recovery_display = RecoveryDisplay.new
    if params[:stolen_record_id].present?
      @recovery_display.from_stolen_record(params[:stolen_record_id])
      @stolen_record = @recovery_display.stolen_record
      @bike = @recovery_display.bike && @recovery_display.bike.decorate
    end
  end

  def show
    if params[:id] == "bust_cache"
      clear_index_wrap_cache
      flash[:success] = "Recovery Display Cache busted"
      redirect_to admin_recovery_displays_url
    else
      redirect_to edit_admin_recovery_display_url
    end
  end

  def edit
    @stolen_record = @recovery_display.stolen_record
    @bike = @recovery_display.bike && @recovery_display.bike.decorate
  end

  def update
    if @recovery_display.update_attributes(permitted_parameters)
      clear_index_wrap_cache
      flash[:success] = "Recovery display saved!"
      redirect_to admin_recovery_displays_url
    else
      render action: :edit
    end
  end

  def create
    @recovery_display = RecoveryDisplay.create(permitted_parameters)
    if @recovery_display.save
      clear_index_wrap_cache
      flash[:success] = "Recovery display created!"
      redirect_to admin_recovery_displays_url
    else
      render action: :new
    end
  end

  def destroy
    @recovery_display.destroy
    clear_index_wrap_cache
    redirect_to admin_recovery_displays_url
  end

  protected

  def permitted_parameters
    params.require(:recovery_display)
          .permit(%i(stolen_record_id quote quote_by recovered_at link image
                     remote_image_url date_input remove_image))
  end

  def clear_index_wrap_cache
    I18n.available_locales.each do |locale|
      expire_fragment(["root_recovery_stories", "locale", locale])
    end
  end

  def find_recovery_displays
    @recovery_display = RecoveryDisplay.find(params[:id])
    raise ActionController::RoutingError.new("Not Found") unless @recovery_display.present?
  end
end
