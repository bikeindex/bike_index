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
    if @marketplace_listing.errors.any? || flash[:error].present?
    else
      flash[:success] ||= translation(:marketplace_listing_updated)
      return if return_to_if_present
    end
    edit_template = params[:edit_template] || "marketplace"
    edit_bike_url(@bike, edit_template:)
  end

  private

  def find_marketplace_listing
    pp params
    if params[:id].first == "b"
      @marketplace_listing = MarketplaceListing.find(params[:id])
    else
      @marketplace_listing = MarketplaceListing.find(params[:id])
    end
  end

  def ensure_user_allowed_to_edit!
    return if @marketplace_listing.item&.authorized?(current_user)

    flash[:error] = translation(:you_dont_own_that, item_type: @marketplace_listing.item_type_display)
    redirect_back(fallback_location: user_root_url) && return
  end
end
