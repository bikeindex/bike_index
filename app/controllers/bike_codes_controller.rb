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
        flash[:success] = "#{@bike_code.kind.titleize} #{@bike_code.code} - #{@bike_code.claimed? ? 'claimed' : 'unclaimed'}"
        if @bike_code.bike.present?
          redirect_to bike_path(@bike_code.bike_id) and return
        end
      end
    end
    redirect_to :back
  end

  protected

  def bike_code_code
    params.dig(:bike_code, :code) || params[:id]
  end

  def find_bike_code
    unless current_user.present?
      flash[:error] = "You must be signed in to do that"
      redirect_to :back
      return
    end
    bike_code = BikeCode.lookup_with_fallback(bike_code_code, organization_id: current_organization&.id, user: current_user)
    # use the loosest lookup, but only permit it if the user can claim that
    @bike_code = bike_code if bike_code.present? && bike_code.claimable_by?(current_user)
    return @bike_code if @bike_code.present?
    flash[:error] = "Unable to find sticker with code: #{bike_code_code}"
    redirect_to :back and return
  end

  def redirect_back
    if params[:id].present?
      redirect_to scanned_bike_path(params[:id], organization_id: params[:organization_id]) and return
    else
      redirect_to user_root_url and return
    end
  end
end
