module Bikes
  class RecoveryController < Bikes::BaseController
    skip_before_action :ensure_user_allowed_to_edit
    before_action :ensure_token_match!

    # The token goes in the session rather than the form's URL, so page js never sees it -
    # Bikes::RecoveredController takes it from there
    def edit
      session[:recovery_link_token] = params[:token]
      redirect_to new_bike_recovered_path(@bike)
    end

    def update
      unless @stolen_record.add_recovery_information(permitted_params.to_h)
        session[:recovery_link_token] = params[:token]
        return redirect_to(bike_path(@bike))
      end

      EmailJobs::RecoveredFromLinkJob.perform_async(@stolen_record.id)
      # Lets whoever followed the link see the recovered page without signing in
      session[:recovered_bike_id] = @bike.id
      redirect_to bike_recovered_path(@bike)
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

        flash[:notice] = translation(:already_recovered)
      else
        flash[:error] = translation(:incorrect_token)
      end
      redirect_to(bike_path(@bike)) && return
    end
  end
end
