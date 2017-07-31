module Bikes
  class RecoveryController < ApplicationController
    before_filter :find_bike
    before_filter :ensure_token_match!
    layout 'application_revised'

    def edit
    end

    private

    def find_bike
      @bike = Bike.unscoped.find(params[:bike_id])
    rescue ActiveRecord::StatementInvalid => e
      raise e.to_s =~ /PG..NumericValueOutOfRange/ ? ActiveRecord::RecordNotFound : e
    end

    def ensure_token_match!
      @stolen_record = @bike && StolenRecord.unscoped
                                            .where(bike_id: @bike.id,
                                                   recovery_link_token: params[:token]).first
      return true if @stolen_record.present?
      flash[:error] = 'Incorrect Token, check your email again'
      redirect_to bike_path(@bike) and return
    end
  end
end
