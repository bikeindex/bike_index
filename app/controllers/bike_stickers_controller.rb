class BikeStickersController < ApplicationController
  before_action :find_bike_sticker

  def update
    @bike_sticker.claim_if_permitted(user: current_user, bike: params[:bike_id])
    if @bike_sticker.errors.any?
      flash[:error] = @bike_sticker.errors.full_messages.to_sentence
    else
      flash[:success] = "#{@bike_sticker.kind.titleize} #{@bike_sticker.code} - #{@bike_sticker.claimed? ? "claimed" : "unclaimed"}"
      if @bike_sticker.bike.present?
        redirect_to(bike_path(@bike_sticker.bike_id)) && return
      end
    end
    redirect_back(fallback_location: root_url)
  end

  protected

  def bike_sticker_code
    params.dig(:bike_sticker, :code) || params[:id]
  end

  def find_bike_sticker
    unless current_user.present?
      flash[:error] = translation(:must_be_signed_in)
      redirect_back(fallback_location: scanned_bike_path(params[:id], organization_id: params[:organization_id]))
      return
    end
    bike_sticker = BikeSticker.lookup_with_fallback(bike_sticker_code, organization_id: passive_organization&.id, user: current_user)
    # use the loosest lookup
    @bike_sticker = bike_sticker if bike_sticker.present?
    return @bike_sticker if @bike_sticker.present?
    flash[:error] = translation(:unable_to_find_sticker, code: bike_sticker_code)
    redirect_back(fallback_location: root_url) && return
  end
end
