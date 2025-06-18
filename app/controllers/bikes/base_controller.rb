class OwnershipNotSavedError < StandardError
end

class BikeServices::UpdatorError < StandardError
end

class Bikes::BaseController < ApplicationController
  before_action :find_bike
  before_action :assign_current_organization
  before_action :ensure_user_allowed_to_edit

  protected

  # Make it possible to assign organization for a view by passing the organization_id parameter - mainly useful for superusers
  # Also provides testable protection against seeing organization info on bikes
  def assign_current_organization
    org = current_organization || passive_organization # actually call #current_organization first
    # If forced false, or no user present, skip everything else
    return true if @current_organization_force_blank || current_user.blank?
    # If there was an organization_id passed, and the user isn't authorized for that org, reset passive_organization to something they can access
    # ... Particularly relevant for scanned stickers, which may be scanned by child orgs - but I think it's the behavior users expect regardless
    if current_user.default_organization.present? && params[:organization_id].present?
      return true if org.present? && current_user.authorized?(org)
      set_passive_organization(current_user.default_organization)
    else
      # If current_user isn't authorized for the organization, force assign nil
      return true if org.blank? || org.present? && current_user.authorized?(org)
      set_passive_organization(nil)
    end
  end

  def find_bike
    # Fix issue with sticker batches #35 & #38
    if params[:id].present? && params[:id].match?(/scanned(uc|ui)\d+/i)
      permitted_params = params.except(:action, :controller, :id).as_json
        .merge(id: params[:id].gsub("scanned", ""))
      redirect_to(scanned_bike_path(permitted_params))
      return
    end
    begin
      @bike = Bike.unscoped.find(params[:bike_id] || params[:id])
    rescue ActiveRecord::StatementInvalid => e
      raise e.to_s.match?(/PG..NumericValueOutOfRange/) ? ActiveRecord::RecordNotFound : e
    end
    return @bike if @bike.visible_by?(current_user)
    fail ActiveRecord::RecordNotFound
  end

  def find_or_new_b_param
    token = params[:b_param_token]
    token ||= params.dig(:bike, :b_param_id_token)
    @bike_sticker = BikeSticker.lookup_with_fallback(params[:bike_sticker], user: current_user)
    @b_param = BParam.find_or_new_from_token(token, user_id: current_user&.id, bike_sticker: @bike_sticker)
  end

  def ensure_user_allowed_to_edit
    @current_ownership = @bike.current_ownership
    type = @bike&.type || "bike"

    return true if @bike.authorize_and_claim_for_user(current_user)

    if @bike.current_impound_record.present?
      error = if @bike.current_impound_record.organized?
        translation(:bike_impounded_by_organization, bike_type: type, org_name: @bike.current_impound_record.organization.name,
          scope: [:controllers, :bikes, :ensure_user_allowed_to_edit])
      else
        translation(:bike_impounded, bike_type: type,
          scope: [:controllers, :bikes, :ensure_user_allowed_to_edit])
      end
    elsif current_user.present?
      error = translation(:you_dont_own_that, bike_type: type,
        scope: [:controllers, :bikes, :ensure_user_allowed_to_edit])
    else
      store_return_to
      error = if @current_ownership && @bike.current_ownership.claimed
        translation(:you_have_to_sign_in, bike_type: type,
          scope: [:controllers, :bikes, :ensure_user_allowed_to_edit])
      else
        translation(:bike_has_not_been_claimed_yet, bike_type: type,
          scope: [:controllers, :bikes, :ensure_user_allowed_to_edit])
      end
    end

    return true unless error.present? # Can't assign directly to flash here, sometimes kick out of edit because other flash error
    flash[:error] = error
    redirect_to(bike_path(@bike)) && return
  end

  def update_organizations_can_edit_claimed(bike, organization_ids)
    organization_ids = Array(organization_ids).map(&:to_i)
    bike.bike_organizations.each do |bike_organization|
      bike_organization.update_attribute :can_not_edit_claimed, !organization_ids.include?(bike_organization.organization_id)
    end
  end

  def assign_bike_stickers(bike_sticker)
    bike_sticker = BikeSticker.lookup_with_fallback(bike_sticker)
    unless bike_sticker.present?
      return flash[:error] = translation(:unable_to_find_sticker, bike_sticker: bike_sticker,
        scope: [:controllers, :bikes, :assign_bike_stickers])
    end
    bike_sticker.claim_if_permitted(user: current_user, bike: @bike)
    if bike_sticker.errors.any?
      flash[:error] = bike_sticker.errors.full_messages
    else
      flash[:success] = translation(:sticker_assigned, bike_sticker: bike_sticker.pretty_code, bike_type: @bike.type,
        scope: [:controllers, :bikes, :assign_bike_stickers])
    end
  end

  def find_token
    # First, deal with claim_token
    if params[:t].present? && @bike.current_ownership.token == params[:t]
      @claim_message = @bike.current_ownership&.claim_message
    end
    # Then deal with parking notification and graduated notification tokens
    @token = params[:parking_notification_retrieved].presence || params[:graduated_notification_remaining].presence
    return false if @token.blank?
    if params[:parking_notification_retrieved].present?
      @matching_notification = @bike.parking_notifications.where(retrieval_link_token: @token).first
      @token_type = @matching_notification&.kind
    elsif params[:graduated_notification_remaining].present?
      @matching_notification = GraduatedNotification.where(bike_id: @bike.id, marked_remaining_link_token: @token).first
      @token_type = "graduated_notification"
    end
    @token_type ||= "parked_incorrectly_notification" # Fallback
  end

  def scanned_id
    params[:id] || params[:scanned_id] || params[:card_id]
  end

  # still manually managing permission of params, so skip it
  def permitted_bparams
    params.except(:parking_notification).as_json # We only want to include parking_notification in authorized endpoints
  end
end
