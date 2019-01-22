class Admin::RecoveriesController < Admin::BaseController
  def index
    if params[:posted]
      @posted = true
      recoveries = StolenRecord.recovery_unposted.includes(:bike).order("date_recovered desc")
    elsif params[:all_recoveries]
      recoveries = StolenRecord.recovered.includes(:bike).order("date_recovered desc")
    else 
      recoveries = StolenRecord.displayable.includes(:bike).order("date_recovered desc")
    end
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @recoveries = recoveries.page(page).per(per_page)
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
    if @stolen_record.update_attributes(permitted_parameters)
      flash[:success] = 'Recovery Saved!'
      redirect_to admin_recoveries_url
    else
      raise StandardError
      render action: :edit
    end
  end

  def approve
    if params[:multipost]
      enqueued = false
      if params[:recovery_selected].present?
        params[:recovery_selected].keys.each do |rid|
          recovery = StolenRecord.unscoped.find(rid)
          unless recovery.recovery_posted && recovery.can_share_recovery == false
            RecoveryNotifyWorker.perform_async(rid.to_i)
            enqueued = true
          end
        end
      end
      if enqueued
        flash[:success] = "Recovery notifications enqueued. Recoveries marked 'can share' haven't been posted, because they need your loving caress."
      else 
        flash[:error] = "No recoveries were selected (or only recoveries you need to caress were)"
      end
      redirect_to admin_recoveries_url
    else
      RecoveryNotifyWorker.perform_async(params[:id].to_i)
      flash[:success] = 'Recovery notification enqueued.'
      redirect_to admin_recoveries_url
    end
  end

  private

  def permitted_parameters
    params.require(:stolen_record).permit(:zipcode, :city, :theft_description, :bike_id, :current, :street, :latitude, :longitude, :date_stolen, :phone, :phone_for_everyone, :phone_for_users, :phone_for_shops, :phone_for_police, :police_report_number, :locking_description, :lock_defeat_description, :country_id, :police_report_department, :state_id, :creation_organization_id, :secondary_phone, :approved, :recieve_notifications, :proof_of_ownership, :date_recovered, :recovered_description, :index_helped_recovery, :can_share_recovery, :recovery_posted, :recovery_tweet, :recovery_share, :create_open311, :estimated_value, :recovery_link_token)
  end
end
