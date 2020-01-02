class BikeStickersController < ApplicationController
  rescue_from ActionController::RedirectBackError, with: :redirect_back # Gross. TODO: Rails 5 update
  before_action :find_bike_sticker

  def update
    if current_user.present? && current_user.authorized?(@bike_sticker)
      @bike_sticker.claim(current_user, params[:bike_id])
      if @bike_sticker.errors.any?
        flash[:error] = @bike_sticker.errors.full_messages.to_sentence
      else
        flash[:success] = "#{@bike_sticker.kind.titleize} #{@bike_sticker.code} - #{@bike_sticker.claimed? ? "claimed" : "unclaimed"}"
        if @bike_sticker.bike.present?
          redirect_to bike_path(@bike_sticker.bike_id) and return
        end
      end
    else
      flash[:error] = translation(:cannot_update, kind: @bike_sticker.kind)
    end
    redirect_to :back
  end

  protected

  def bike_code_code
    params.dig(:bike_sticker, :code) || params[:id]
  end

  def find_bike_sticker
    unless current_user.present?
      flash[:error] = translation(:must_be_signed_in)
      redirect_to :back
      return
    end
    bike_sticker = BikeSticker.lookup_with_fallback(bike_code_code, organization_id: passive_organization&.id, user: current_user)
    # use the loosest lookup, but only permit it if the user can claim that
    @bike_sticker = bike_sticker if bike_sticker.present? && bike_sticker.claimable_by?(current_user)
    return @bike_sticker if @bike_sticker.present?
    flash[:error] = translation(:unable_to_find_sticker, code: bike_code_code)
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
