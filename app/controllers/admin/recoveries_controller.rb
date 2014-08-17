class Admin::RecoveriesController < Admin::BaseController
  def index
    if params[:posted]
      @posted = true
      recoveries = StolenRecord.recovery_unposted.includes(:bike)
    else
      recoveries = StolenRecord.recovered.includes(:bike)
    end
    @recoveries = recoveries.paginate(page: params[:page]).per_page(50)
  end

  def show
    redirect_to edit_admin_recovery_url
  end

  def edit
    @recovery = StolenRecord.unscoped.find(params[:id])
    @bike = @recovery.bike.decorate
  end

  def update
    @stolen_record = StolenRecord.unscoped.find(params[:id])
    if @stolen_record.update_attributes(params[:stolen_record])
      flash[:notice] = "Recovery Saved!"
      redirect_to admin_recoveries_url
    else
      raise StandardError
      render action: :edit
    end
  end

  def approve
    RecoveryNotifyWorker.perform_async(params[:id].first.to_i)
    redirect_to admin_recoveries_url, notice: 'Stolen record notification enqueued.'
    
  end

end
