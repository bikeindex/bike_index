class BikeNotSavedError < StandardError
end

class Admin::RecoveriesController < Admin::BaseController
  before_filter :find_bike, only: [:approve]

  def index
    recoveries = StolenRecord.recovered.includes(:bike)
    @recoveries = recoveries.paginate(page: params[:page]).per_page(50)
  end

  def show
    redirect_to edit_admin_recovery_url
  end

  def edit
    @recovery = StolenRecord.find(params[:id])
    @bike = @recovery.bike.decorate
  end

  def update
    @stolen_record = StolenRecord.find(params[:id])
    if @stolen_record.update_attributes(params[:ownership])
      RecoveryNotifyWorker.perform_async(params[:id])
      flash[:notice] = "Recovery Saved!"
      redirect_to admin_recoveries_url
    else
      render action: :edit
    end
  end

  def approve
    @bike.current_stolen_record.update_attribute :approved, true
    @bike.update_attribute :approved_stolen, true
    ApproveStolenListingWorker.perform_async(@bike.id)
    redirect_to edit_admin_stolen_bike_url(@bike), notice: 'Bike was approved.'
  end

  protected

  def find_bike
    @bike = Bike.unscoped.find(params[:id])
  end
end
