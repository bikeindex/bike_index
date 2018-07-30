module Bikes
  class RecoveryController < ApplicationController
    before_filter :find_bike
    before_filter :ensure_token_match!
    layout 'application_revised'

    def edit
      # redirect to bike show and set session - so the token isn't available to on page js
      # and so we can render show with a modal
      session[:recovery_link_token] = params[:token]
      redirect_to bike_path(@bike)
    end

    def update
      if @stolen_record.add_recovery_information(permitted_params)
        EmailRecoveredFromLinkWorker.perform_async(@stolen_record.id)
        flash[:success] = 'Bike marked recovered! Thank you!'
        redirect_to bike_path(@bike)
      else
        render :edit, bike_id: @bike.id, token: params[:token]
      end
    end

    private

    def permitted_params
      params.require(:stolen_record).permit(:date_recovered, :timezone, :recovered_description,
                                            :index_helped_recovery, :can_share_recovery)
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
        flash[:info] = 'Bike has already been marked recovered!'
      else
        flash[:error] = 'Incorrect Token, check your email again'
      end
      redirect_to bike_path(@bike) and return
    end
  end
end
