class BikeServices::UpdatorError < StandardError
end

class BikeServices::Updator
  class << self
    def permitted_params(params, bike, user)
      # TODO: improve this entire thing. Maybe using BParam.safe_bike_attrs
      # IMPORTANT - needs to handle propulsion_type > propulsion_type_slug coercion
      {
        bike: params.require(:bike).permit(BikeServices::Creator.old_attr_accessible)
      }.as_json
    end

    def updator_attrs(user)
      {updated_by_user_at: Time.current}.merge(user.present? ? {updator_id: user.id} : {})
    end
  end

  def initialize(user:, bike:, current_ownership: nil, params: nil, permitted_params: nil, doorkeeper_app_id: nil)
    @user = user
    @bike = bike
    @bike_params = permitted_params || self.class.permitted_params(params, bike, user)
    @doorkeeper_app_id = doorkeeper_app_id
    @current_ownership = current_ownership
    @currently_stolen = @bike.status_stolen?
  end

  def update_ownership
    registration_info = BikeServices::OwnershipTransferer.registration_info_from_params(@bike_params)
    ownership_id = @bike.current_ownership_id
    new_ownership = BikeServices::OwnershipTransferer.find_or_create(@bike, updator: @user,
      new_owner_email: @bike_params["bike"].delete("owner_email"),
      doorkeeper_app_id: @doorkeeper_app_id, skip_bike_save: true, registration_info:)
    # Don't update bike_params unless new ownership was created
    return if ownership_unchanged?(new_ownership, ownership_id)

    # OwnershipTransferer updates these attributes - remove the parameters in case they were set automatically
    @bike_params["bike"]["is_for_sale"] = false
    @bike_params["bike"]["address_set_manually"] = false
  end

  def update_api_components
    ComponentCreator.new(bike: @bike, b_param: @bike_params).update_components_from_params
  end

  # This is a separate method because it's called in admin
  def update_stolen_record
    BikeServices::StolenRecordUpdator.new(bike: @bike, b_param: BParam.new(params: @bike_params)).update_records
  end

  def set_protected_attributes
    @bike_params["bike"]["serial_number"] = @bike.serial_number
    @bike_params["bike"]["manufacturer_id"] = @bike.manufacturer_id
    @bike_params["bike"]["manufacturer_other"] = @bike.manufacturer_other
    @bike_params["bike"]["creation_organization_id"] = @bike.creation_organization_id
    @bike_params["bike"].delete("creator")
    @bike_params["bike"]["example"] = @bike.example
    @bike_params["bike"].delete("user_hidden")
  end

  def update_available_attributes
    ensure_ownership!
    set_protected_attributes
    update_ownership
    update_api_components if @bike_params["components"].present?
    # Skips a few REGISTRATION_INFO_ATTRS
    update_attrs = @bike_params["bike"].except("stolen_records_attributes", "impound_records_attributes",
      "address_record_attributes", "ios_version", "is_bulk", "is_new", "is_pos")

    update_attrs.merge!(address_record_attributes(update_attrs, @bike_params["bike"]["address_record_attributes"]))

    propulsion_updates = update_attrs.keys & %w[cycle_type cycle_type_name propulsion_type propulsion_type_slug]
    if propulsion_updates.any?
      # Ensure valid propulsion type
      cycle_type = update_attrs["cycle_type"] || update_attrs["cycle_type_name"] || @bike.cycle_type
      @bike.cycle_type = CycleType.friendly_find(cycle_type)&.slug || "bike"
      @bike.propulsion_type_slug = update_attrs["propulsion_type"] || update_attrs["propulsion_type_slug"] || @bike.propulsion_type
      update_attrs = update_attrs.except(*propulsion_updates)
    end

    if @bike.update(update_attrs.merge(self.class.updator_attrs(@user)))
      update_stolen_record
      update_impound_record
    end
    CallbackJob::AfterBikeSaveJob.perform_async(@bike.id) if @bike.present? # run immediately
    remove_blank_components
    @bike
  end

  private

  def ensure_ownership!
    return true if @current_ownership && @current_ownership.owner == @user # So we can pass in ownership and skip query
    return true if @bike.authorized?(@user)

    raise BikeServices::UpdatorError, "Oh no! It looks like you don't own that bike."
  end

  def ownership_unchanged?(new_ownership, previous_ownership_id)
    return true unless new_ownership.valid?

    new_ownership.id == previous_ownership_id
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

  # TODO: Remove :update_attrs - only need address_record_attributes - once backfill is finished - #2922
  def address_record_attributes(update_attrs, address_record_attributes)
    if address_record_attributes.blank?
      address_record_attributes = update_attrs.slice("city", "country_id", "street")
        .merge(region_record_id: update_attrs["state_id"], postal_code: update_attrs["zipcode"])
    end
    return {} if address_record_attributes.values.reject(&:blank?).none?

    address_record_attributes["kind"] = "bike"
    address_record_attributes["bike_id"] = @bike.id
    address_record_attributes["id"] = (@bike.address_record&.kind == "bike") ? @bike.address_record_id : nil
    address_set_manually = address_record_attributes.slice("street", "city", "postal_code").values.reject(&:blank?).any?

    {address_record_attributes:}.merge(address_set_manually ? {address_set_manually: true} : {})
  end
end
