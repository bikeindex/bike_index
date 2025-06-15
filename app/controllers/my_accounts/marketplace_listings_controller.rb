# frozen_string_literal: true

class MyAccounts::MarketplaceListingsController < ApplicationController
  before_action :find_marketplace_listing
  before_action :ensure_user_allowed_to_edit!

  def update
    if @marketplace_listing.update(permitted_params_with_permitted_address)
      if @new_status.present?

      else
        flash[:success] ||= translation(:marketplace_listing_updated)
      end
      return if return_to_if_present
    else
      flash[:error] = @marketplace_listing.errors.full_messages.to_sentence
    end
    edit_template = params[:edit_template] || "marketplace"
    redirect_to edit_bike_url(@bike, edit_template:)
  end

  private

  def permitted_params_with_permitted_address
    pparams = permitted_params

    # Delete the address attributes if :user_account_address is set
    if InputNormalizer.boolean(pparams[:address_record_attributes][:user_account_address])
      pparams.delete(:address_record_attributes)
      # NOTE: Not user, or else admin edits overwrite the user's address
      pparams[:address_record_id] = @bike.user&.address_record_id
    end
    # Only update the address if it's a marketplace_listing address by the item's user
    if (address_record_id = pparams.dig(:address_record_attributes, :id))
      unless AddressRecord.marketplace_listing.where(user_id: @bike.user&.id, id: address_record_id).any?
        pparams[:address_record_attributes].delete(:id)
        # reassign to the marketplace_listing's address_record ID if that's what should be done
        if @marketplace_listing.address_record&.kind == "marketplace_listing"
          pparams[:address_record_attributes][:id] = @marketplace_listing.address_record_id
        end
      end
    end
    new_status = pparams[:status]
    if %w[draft for_sale].include?(pparams[:status]) && @marketplace_listing.status != new_status
      @new_status = new_status
    end

    pparams
  end

  def permitted_params
    params.require(:marketplace_listing)
      .permit(:condition, :amount_with_nil, :price_negotiable, :description, :primary_activity_id,
        address_record_attributes: (AddressRecord.permitted_params + %i[id user_account_address]))
  end

  def find_marketplace_listing
    @bike = Bike.unscoped.find(params[:id].delete_prefix("b"))
    ml_id = params.dig(:marketplace_listing, :id)

    @marketplace_listing = @bike.marketplace_listings.find_by(id: ml_id) if ml_id.present?
    @marketplace_listing ||= MarketplaceListing.find_or_build_current_for(@bike)
  end

  def ensure_user_allowed_to_edit!
    # return if @marketplace_listing&.authorized?(current_user)
    return if @bike&.authorized?(current_user)

    flash[:error] = translation(:you_dont_own_that, item_type: @bike&.type)
    redirect_back(fallback_location: user_root_url) && return
  end
end
