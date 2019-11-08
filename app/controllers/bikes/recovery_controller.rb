module Bikes
  class RecoveryController < ApplicationController
    before_filter :find_bike
    before_filter :ensure_token_match!

    def edit
      # redirect to bike show and set session - so the token isn't available to on page js
      # and so we can render show with a modal
      session[:recovery_link_token] = params[:token]
      redirect_to bike_path(@bike)
    end

    def update
      if @stolen_record.add_recovery_information(permitted_params)
        EmailRecoveredFromLinkWorker.perform_async(@stolen_record.id)
        flash[:success] = translation(:bike_recovered)
        redirect_to bike_path(@bike)
      else
        session[:recovery_link_token] = params[:token]
        redirect_to bike_path(@bike)
      end
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

    def find_bike
      @bike = Bike.unscoped.find(params[:bike_id])
    rescue ActiveRecord::StatementInvalid => e
      raise e.to_s =~ /PG..NumericValueOutOfRange/ ? ActiveRecord::RecordNotFound : e
    end

    def ensure_token_match!
      @stolen_record = StolenRecord.find_matching_token(bike_id: @bike && @bike.id,
                                                        recovery_link_token: params[:token])
      if @stolen_record.present?
        return true if @bike.stolen
        flash[:info] = translation(:already_recovered)
      else
        flash[:error] = translation(:incorrect_token)
      end
      redirect_to bike_path(@bike) and return
    end
  end
end
