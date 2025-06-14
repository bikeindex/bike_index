# frozen_string_literal: true

class MyAccounts::MarketplaceListingsController < ApplicationController
  before_action :find_marketplace_listing
  before_action :ensure_user_allowed_to_edit!

  def update
    if @marketplace_listing.publish!
      flash[:success] = translation(:item_published_for_sale, item_type: @marketplace_listing.item_type_display)
    else
      flash[:error] = @marketplace_listing.errors.full_messages.to_sentence
    end

    redirect_back(fallback_location: user_root_url)
  end

  private

  def find_marketplace_listing
    @marketplace_listing = MarketplaceListing.find(params[:id])
  end

  def ensure_user_allowed_to_edit!
    return if @marketplace_listing.item&.authorized?(current_user)

    flash[:error] = translation(:you_dont_own_that, item_type: @marketplace_listing.item_type_display)
    redirect_back(fallback_location: user_root_url) && return
  end
end
