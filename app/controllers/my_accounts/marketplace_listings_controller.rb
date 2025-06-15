# frozen_string_literal: true

class MyAccounts::MarketplaceListingsController < ApplicationController
  before_action :find_marketplace_listing
  # before_action :ensure_user_allowed_to_edit!

  def update
    # if @marketplace_listing.publish!
    #   flash[:success] = translation(:item_published_for_sale, item_type: @marketplace_listing.item_type_display)
    # else
    #   flash[:error] = @marketplace_listing.errors.full_messages.to_sentence
    # end

    # redirect_back(fallback_location: user_root_url)
    if @marketplace_listing.update(permitted_update_params)
      flash[:success] ||= translation(:marketplace_listing_updated)
      return if return_to_if_present
    end
    edit_template = params[:edit_template] || "marketplace"
    edit_bike_url(@bike, edit_template:)
  end

  private

  def permitted_update_params
    pparams = params.require(:marketplace_listing).permit(MarketplaceListing.seller_permitted_parameters)

    if InputNormalizer.boolean(pparams[:address_record_attributes][:user_account_address])
      pparams.delete(:address_record_attributes)
      # NOTE: Not user, or else admin edits overwrite the user's address
      pparams[:address_record_id] = @bike.user&.address_record_id
    end

    pparams
  end

  def find_marketplace_listing
    @bike = Bike.unscoped.find(params[:id].delete_prefix("b"))
    ml_id = params.dig(:marketplace_listing, :id)

    @marketplace_listing = @bike.marketplace_listings.find_by(id: ml_id) if ml_id.present?
    @marketplace_listing ||= MarketplaceListing.find_or_build_current_for(@bike)
  end

  def ensure_user_allowed_to_edit!
    pp "---"
    return if @bike&.authorized?(current_user)
    pp "[cc[ccc"

    flash[:error] = translation(:you_dont_own_that, item_type: @bike&.type)
    redirect_back(fallback_location: user_root_url) && return
  end
end
