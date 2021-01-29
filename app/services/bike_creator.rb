class BikeCreator
  # Used to be in Bike - but now it's here. Eventually, we should actually do permitted params handling in here
  # ... and have separate permitted params in bikeupdator
  def self.old_attr_accessible
    (%i[manufacturer_id manufacturer_other serial_number
      serial_normalized made_without_serial extra_registration_number
      creation_organization_id manufacturer year thumb_path name
      current_stolen_record_id abandoned frame_material cycle_type frame_model number_of_seats
      handlebar_type handlebar_type_other frame_size frame_size_number frame_size_unit
      rear_tire_narrow front_wheel_size_id rear_wheel_size_id front_tire_narrow
      primary_frame_color_id secondary_frame_color_id tertiary_frame_color_id paint_id paint_name
      propulsion_type street zipcode country_id state_id city belt_drive
      coaster_brake rear_gear_type_slug rear_gear_type_id front_gear_type_slug front_gear_type_id description owner_email
      timezone date_stolen receive_notifications phone creator creator_id image
      components_attributes b_param_id embeded embeded_extended example hidden organization_affiliation
      stock_photo_url pdf send_email skip_email other_listing_urls listing_order approved_stolen
      marked_user_hidden marked_user_unhidden b_param_id_token is_for_sale bike_organization_ids] +
      [stolen_records_attributes: StolenRecordUpdator.old_attr_accessible,
       components_attributes: Component.old_attr_accessible]
    ).freeze
  end

  def initialize(b_param = nil, location: nil)
    @b_param = b_param
    @bike = nil
    @location = location
  end

  def build_bike(new_attrs = {})
    bike = @b_param.build_bike(new_attrs)
    bike = verify(bike)
    bike.attributes = default_parking_notification_attrs(@b_param, bike) if @b_param.unregistered_parking_notification?
    bike = add_required_attributes(bike)
    add_front_wheel_size(bike)
  end

  def create_bike
    add_bike_book_data
    @bike = find_or_build_bike
    return @bike if @bike.errors.present?
    save_bike(@bike)
  end

  private

  def creation_state_attributes
    {
      is_bulk: @b_param.is_bulk,
      is_pos: @b_param.is_pos,
      is_new: @b_param.is_new,
      origin: @b_param.origin,
      status: @b_param.status,
      bulk_import_id: @b_param.params["bulk_import_id"],
      creator_id: @b_param.creator_id,
      can_edit_claimed: @b_param.unregistered_parking_notification?,
      organization_id: @bike.creation_organization_id
    }
  end

  # Previously all of this stuff was public.
  # In an effort to refactor and simplify, anything not accessed outside of this class was explicitly made private (PR#1478)

  def add_bike_book_data
    return nil unless @b_param && @b_param.bike.present? && @b_param.manufacturer_id.present?
    return nil unless @b_param.bike["frame_model"].present? && @b_param.bike["year"].present?
    bb_data = BikeBookIntegration.new.get_model({
      manufacturer: Manufacturer.find(@b_param.bike["manufacturer_id"]).name,
      year: @b_param.bike["year"],
      frame_model: @b_param.bike["frame_model"]
    })

    return true unless bb_data && bb_data["bike"].present?
    @b_param.params["bike"]["cycle_type"] = bb_data["bike"]["cycle_type"] if bb_data["bike"] && bb_data["bike"]["cycle_type"].present?
    if bb_data["bike"]["paint_description"].present?
      @b_param.params["bike"]["paint_name"] = bb_data["bike"]["paint_description"] unless @b_param.params["bike"]["paint_name"].present?
    end
    if bb_data["bike"]["description"].present?
      if @b_param.params["bike"]["description"].present?
        @b_param.params["bike"]["description"] += " #{bb_data["bike"]["description"]}"
      else
        @b_param.params["bike"]["description"] = bb_data["bike"]["description"]
      end
    end
    @b_param.params["bike"]["rear_wheel_bsd"] = bb_data["bike"]["rear_wheel_bsd"] if bb_data["bike"]["rear_wheel_bsd"].present?
    @b_param.params["bike"]["rear_tire_narrow"] = bb_data["bike"]["rear_tire_narrow"] if bb_data["bike"]["rear_tire_narrow"].present?
    @b_param.params["bike"]["stock_photo_url"] = bb_data["bike"]["stock_photo_url"] if bb_data["bike"]["stock_photo_url"].present?
    @b_param.params["components"] = bb_data["components"] && bb_data["components"].map { |c| c.merge("is_stock" => true) }
    @b_param.clean_params # if we just rely on the before_save filter, @b_param needs to be reloaded
    @b_param.save if @b_param.id.present?
    @b_param
  end

  def clear_bike(bike)
    find_or_build_bike
    bike.errors.messages.each do |message|
      @bike.errors.add(message[0], message[1][0])
    end
    bike.ownerships.destroy_all
    bike.creation_states.destroy_all
    bike.destroy
    @bike
  end

  def validate_record(bike)
    return clear_bike(bike) if bike.errors.present?
    @b_param.find_duplicate_bike(bike) if @b_param.no_duplicate?
    if @b_param.created_bike.present?
      clear_bike(bike)
      @bike = @b_param.created_bike
    elsif @b_param.id.present? # Only update b_param if it exists
      @b_param.update_attributes(created_bike_id: bike.id, bike_errors: nil)
    end
    @bike
  end

  def save_bike(bike)
    bike.set_location_info
    bike.attributes = Geohelper.address_hash_from_geocoder_result(@location) unless bike.latitude.present?
    bike.save
    @bike = BikeCreatorAssociator.new(@b_param).associate(bike)
    validate_record(@bike)
    # We don't want to create an extra creation_state if there was a duplicate.
    # Also - we assume if there is a creation_state, that the bike successfully went through creation
    if @bike.present? && @bike.id.present? && @bike.creation_state.blank?
      @bike.creation_states.create(creation_state_attributes)
      AfterBikeSaveWorker.perform_async(@bike.id)

      if @b_param.bike_sticker.present? && @bike.creation_organization.present?
        bike_sticker = BikeSticker.lookup_with_fallback(@b_param.bike_sticker, organization_id: @bike.creation_organization.id)
        bike_sticker&.claim(user: @bike.creator, bike: @bike.id, organization: @bike.creation_organization)
      end
      if @b_param.unregistered_parking_notification?
        # We skipped setting address, with default_parking_notification_attrs, notification will update it
        ParkingNotification.create!(@b_param.parking_notification_params)
      end
    end

    @bike
  end

  def find_or_build_bike
    if @b_param&.created_bike&.present?
      return @bike = @b_param.created_bike
    end
    @bike = build_bike
    @bike
  end

  def add_front_wheel_size(bike)
    return bike unless bike.rear_wheel_size_id.present? && bike.front_wheel_size_id.blank?
    bike.front_wheel_size_id = bike.rear_wheel_size_id
    bike.front_tire_narrow = bike.rear_tire_narrow
    bike
  end

  def add_required_attributes(bike)
    bike.propulsion_type ||= "foot-pedal"
    bike
  end

  def default_parking_notification_attrs(b_param, bike)
    attrs = {
      skip_status_update: true,
      skip_geocoding: true,
      status: "unregistered_parking_notification",
      marked_user_hidden: true
    }
    # We want to force not sending email
    if b_param.params.dig("bike", "send_email").blank?
      b_param.update_attribute :params, b_param.params.merge("bike" => b_param.params["bike"].merge("send_email" => "false"))
    end
    if bike.owner_email.blank?
      attrs[:owner_email] = b_param.creation_organization&.auto_user&.email.presence || b_param.creator.email
    end
    attrs[:serial_number] = "unknown" unless bike.serial_number.present?
    attrs
  end

  def verify(bike)
    bike = check_organization(bike)
    check_example(bike)
  end

  # Previously in BikeCreatorOrganizer - but that was trashed, so now it's just here
  def check_organization(bike)
    organization_id = @b_param.params.dig("creation_organization_id").presence ||
      @b_param.params.dig("bike", "creation_organization_id")
    organization = Organization.friendly_find(organization_id)
    if organization.present? && !organization.suspended?
      bike.creation_organization_id = organization.id
      bike.creator_id ||= organization.auto_user_id
    else
      if organization&.suspended?
        bike.errors.add(:creation_organization, "Oh no! #{organization.name} is currently suspended. Contact us if this is a surprise.")
      end
      # Since there wasn't a valid organization, blank the organization
      bike.creation_organization_id = nil
    end
    bike
  end

  def check_example(bike)
    example_org = Organization.example
    bike.creation_organization_id = example_org.id if @b_param.params && @b_param.params["test"]
    if bike.creation_organization_id.present? && example_org.present?
      bike.example = true if bike.creation_organization_id == example_org.id
    else
      bike.example = false
    end
    bike
  end
end
