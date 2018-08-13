class BikeCodesController < ApplicationController
  rescue_from ActionController::RedirectBackError, with: :redirect_back # Gross. TODO: Rails 5 update
  before_filter :find_bike_code

  def update
    if !@bike_code.claimable_by?(current_user)
      flash[:error] = "You can't update that #{@bike_code.kind}. Please contact support@bikeindex.org if you think you should be able to"
    else
      @bike_code.claim(current_user, params[:bike_id])
      if @bike_code.errors.any?
        flash[:error] = @bike_code.errors.full_messages.to_sentence
      else
        flash[:success] = "#{@bike_code.kind.titleize} #{@bike_code.claimed? ? "claimed" : "unclaimed"}"
      end
    end
    redirect_to :back
  end

  protected

  def find_bike_code
    unless current_user.present?
      flash[:error] = "You must be signed in to do that"
      redirect_to :back
      return
    end
    @bike_code = BikeCode.lookup(params[:id], organization_id: params[:organization_id])
    raise ActiveRecord::RecordNotFound unless @bike_code.present?
  end

  def redirect_back
    redirect_to scanned_bike_path(params[:id], organization_id: params[:organization_id])
    return
  end
end
