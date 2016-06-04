class Admin::RecoveryDisplaysController < Admin::BaseController
  before_filter :find_recovery_displays, only: [:edit, :update, :destroy]

  def index
    @recovery_displays = RecoveryDisplay.all
  end

  def new
    @recovery_display = RecoveryDisplay.new
    if params[:stolen_record_id].present?
      @recovery_display.from_stolen_record(params[:stolen_record_id])
      @bike = @recovery_display.bike
    end
  end

  def show 
    redirect_to edit_admin_recovery_display_url
  end

  def edit
    @bike = @recovery_display.bike
  end

  def update
    if @recovery_display.update_attributes(params[:recovery_display])
      clear_index_wrap_cache
      flash[:success] = 'Recovery display saved!'
      redirect_to admin_recovery_displays_url
    else
      render action: :edit
    end
  end

  def create
    @recovery_display = RecoveryDisplay.create(params[:recovery_display])
    if @recovery_display.save
      clear_index_wrap_cache
      flash[:success] = 'Recovery display created!'
      redirect_to admin_recovery_displays_url
    else
      render action: :new
    end
  end

  def destroy
    @recovery_display.destroy
    redirect_to admin_recovery_displays_url
  end

  protected

  def clear_index_wrap_cache
    expire_fragment 'root_head_wrap'
  end

  def find_recovery_displays
    @recovery_display = RecoveryDisplay.find(params[:id])
    raise ActionController::RoutingError.new('Not Found') unless @recovery_display.present?
  end
end
