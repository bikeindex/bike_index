class Bikes::RecoveryController < Bikes::BaseController
  skip_before_action :ensure_user_allowed_to_edit
  before_action :ensure_token_match!

  def edit
    # redirect to bike show and set session - so the token isn't available to on page js
    # and so we can render show with a modal
    session[:recovery_link_token] = params[:token]
    redirect_to bike_path(@bike)
  end

  def update
    if @stolen_record.add_recovery_information(permitted_params.to_h)
      EmailRecoveredFromLinkWorker.perform_async(@stolen_record.id)
      flash[:success] = I18n.t(:bike_recovered)
    else
      session[:recovery_link_token] = params[:token]
    end
    redirect_to bike_path(@bike)
  end

  private

  def permitted_params
    params.require(:stolen_record).permit(
      :recovered_at,
      :timezone,
      :recovered_description,
      :index_helped_recovery,
      :can_share_recovery
    ).merge(recovering_user_id: current_user&.id)
  end

  def ensure_token_match!
    @stolen_record = StolenRecord.find_matching_token(bike_id: @bike&.id,
      recovery_link_token: params[:token])
    if @stolen_record.present?
      return true if @bike.status_stolen?
      flash[:info] = I18n.t(:already_recovered)
    else
      flash[:error] = I18n.t(:incorrect_token)
    end
    redirect_to(bike_path(@bike)) && return
  end
end
