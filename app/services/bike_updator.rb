class BikeUpdatorError < StandardError
end

class BikeUpdator
  class << self
    def permitted_params(params, bike, user)
      # TODO: improve this entire thing. Maybe using BParam.safe_bike_attrs
      # IMPORTANT - needs to handle propulsion_type > propulsion_type_slug coercion
      {
        bike: params.require(:bike).permit(BikeCreator.old_attr_accessible)
      }.as_json
    end
  end

  def initialize(user:, bike:, current_ownership: nil, params: nil, permitted_params: nil)
    @user = user
    @bike = bike
    @bike_params = permitted_params || self.class.permitted_params(params, bike, user)
    @current_ownership = current_ownership
    @currently_stolen = @bike.status_stolen?
  end

  def update_ownership
    # Because this is a mess, managed independently in ProcessImpoundUpdatesJob
    new_owner_email = EmailNormalizer.normalize(@bike_params["bike"].delete("owner_email"))
    return false if new_owner_email.blank? || @bike.owner_email == new_owner_email

    # Since we've deleted the owner_email from the update hash, we have to assign it here
    # This is required because ownership_creator uses it :/ - not a big fan of this side effect though
    @bike.owner_email = new_owner_email
    @bike.attributes = updator_attrs
    if @bike.unregistered_parking_notification?
      @bike.update(status: "status_with_owner", marked_user_unhidden: true)
    elsif !@skip_ownership_bike_save
      # If this is not called from update_available_attributes, save to set the updator attributes
      @bike.save
    end
    # If updator is a member of the creation organization, add org to the new ownership!
    ownership_org = @bike.current_ownership&.organization
    # If previous ownership was with_owner, this should be too
    status = "status_with_owner" if @bike.current_ownership&.status_with_owner?
    @bike.ownerships.create(owner_email: new_owner_email,
      creator: @user,
      origin: "transferred_ownership",
      status:,
      organization: @user&.member_of?(ownership_org) ? ownership_org : nil,
      skip_email: @bike_params.dig("bike", "skip_email"))

    # If the bike is a unregistered_parking_notification, switch to being a normal bike, since it's been sent to a new owner
    @bike_params["bike"]["is_for_sale"] = false # Because, it's been given to a new owner
    @bike_params["bike"]["address_set_manually"] = false # Because we don't want the old owner address
  end

  def update_api_components
    ComponentCreator.new(bike: @bike, b_param: @bike_params).update_components_from_params
  end

  # This is a separate method because it's called in admin
  def update_stolen_record
    StolenRecordUpdator.new(bike: @bike, b_param: BParam.new(params: @bike_params)).update_records
  end

  def set_protected_attributes
    @bike_params["bike"]["serial_number"] = @bike.serial_number
    @bike_params["bike"]["manufacturer_id"] = @bike.manufacturer_id
    @bike_params["bike"]["manufacturer_other"] = @bike.manufacturer_other
    @bike_params["bike"]["creation_organization_id"] = @bike.creation_organization_id
    @bike_params["bike"]["creator"] = @bike.creator
    @bike_params["bike"]["example"] = @bike.example
    @bike_params["bike"]["user_hidden"] = @bike.user_hidden
  end

  def update_available_attributes
    ensure_ownership!
    set_protected_attributes
    @skip_ownership_bike_save = true # Don't save bike an extra time in update ownership
    update_ownership
    update_api_components if @bike_params["components"].present?
    update_attrs = @bike_params["bike"].except("stolen_records_attributes", "impound_records_attributes")
    if update_attrs.slice("street", "city", "zipcode").values.reject(&:blank?).any?
      @bike.address_set_manually = true
    end

    propulsion_updates = update_attrs.keys & %w[cycle_type cycle_type_name propulsion_type propulsion_type_slug]
    if propulsion_updates.any?
      # Ensure valid propulsion type
      cycle_type = update_attrs["cycle_type"] || update_attrs["cycle_type_name"] || @bike.cycle_type
      @bike.cycle_type = CycleType.friendly_find(cycle_type)&.slug || "bike"
      @bike.propulsion_type_slug = update_attrs["propulsion_type"] || update_attrs["propulsion_type_slug"] || @bike.propulsion_type
      update_attrs = update_attrs.except(*propulsion_updates)
    end
    if @bike.update(update_attrs.merge(updator_attrs))
      update_stolen_record
      update_impound_record
    end
    ::Callbacks::AfterBikeSaveJob.perform_async(@bike.id) if @bike.present? # run immediately
    remove_blank_components
    @bike
  end

  private

  def ensure_ownership!
    return true if @current_ownership && @current_ownership.owner == @user # So we can pass in ownership and skip query
    return true if @bike.authorized?(@user)
    raise BikeUpdatorError, "Oh no! It looks like you don't own that bike."
  end

  def remove_blank_components
    return false unless @bike.components.any?
    @bike.components.each do |c|
      c.destroy unless c.ctype_id.present? || c.description.present?
    end
  end

  # This is very hacky, but it's something. Improve sometime
  def update_impound_record
    # These are sanitized - because they're actually permitted in the bikes controller action
    impound_params = @bike_params.dig("bike", "impound_records_attributes")&.values&.reject(&:blank?)&.first
    impound_record = @bike.current_impound_record
    return unless impound_params.present? && impound_record.present?
    impound_record.update(impound_params)
  end

  def updator_attrs
    {updated_by_user_at: Time.current}.merge(@user.present? ? {updator_id: @user.id} : {})
  end
end
