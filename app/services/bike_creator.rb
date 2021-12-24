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
      components_attributes b_param_id embeded embeded_extended example organization_affiliation student_id
      stock_photo_url pdf send_email skip_email listing_order approved_stolen
      marked_user_hidden marked_user_unhidden b_param_id_token is_for_sale bike_organization_ids] +
      [
        stolen_records_attributes: StolenRecordUpdator.old_attr_accessible,
        impound_records_attributes: permitted_impound_attrs,
        components_attributes: %i[id cmodel_name year ctype ctype_id ctype_other manufacturer manufacturer_id mnfg_name
          manufacturer_other description bike_id bike serial_number front rear front_or_rear _destroy]
      ]
    ).freeze
  end

  def self.permitted_impound_attrs
    %w[street city state zipcode country timezone impounded_at_with_timezone display_id impounded_description].freeze
  end

  def initialize(b_param = nil, location: nil)
    @b_param = b_param
    @location = location
  end

  attr_reader :b_param

  def build_bike(new_attrs = {})
    bike = Bike.new(@b_param.safe_bike_attrs(new_attrs))
    # Use bike status because it takes into account new_attrs
    bike.build_new_stolen_record(@b_param.stolen_attrs) if bike.status_stolen?
    bike.build_new_impound_record(@b_param.impound_attrs) if bike.status_impounded?
    bike = check_organization(bike)
    bike = check_example(bike)
    bike.attributes = default_parking_notification_attrs(@b_param, bike) if @b_param.unregistered_parking_notification?
    bike = add_required_attributes(bike)
    add_front_wheel_size(bike)
  end

  def create_bike
    add_bike_book_data(@b_param)
    bike = find_or_build_bike(@b_param)
    pp bike.errors.full_messages, bike.id
    # There could be errors during the build - or during the save
    save_bike(bike) if bike.errors.none?
    if bike.errors.any?
      @b_param&.update(bike_errors: bike.cleaned_error_messages)
    end
    pp bike.errors.full_messages, bike.id
    bike
  end

  # Called from ImageAssociatorWorker, so can't be private
  def attach_photo(bike)
    return true unless @b_param.image.present?
    public_image = PublicImage.new(image: @b_param.image)
    public_image.imageable = bike
    public_image.save
    @b_param.update(image_processed: true)
    bike.reload
  end

  private

  # Previously all of this stuff was public.
  # In an effort to refactor and simplify, anything not accessed outside of this class was explicitly made private (PR#1478)

  def add_bike_book_data(b_param)
    return nil unless b_param && b_param.bike.present? && b_param.manufacturer_id.present?
    return nil unless b_param.bike["frame_model"].present? && b_param.bike["year"].present?
    bb_data = BikeBookIntegration.new.get_model({
      manufacturer: Manufacturer.find(b_param.bike["manufacturer_id"]).name,
      year: b_param.bike["year"],
      frame_model: b_param.bike["frame_model"]
    })

    return true unless bb_data && bb_data["bike"].present?
    b_param.params["bike"]["cycle_type"] = bb_data["bike"]["cycle_type"] if bb_data["bike"] && bb_data["bike"]["cycle_type"].present?
    if bb_data["bike"]["paint_description"].present?
      b_param.params["bike"]["paint_name"] = bb_data["bike"]["paint_description"] unless b_param.params["bike"]["paint_name"].present?
    end
    if bb_data["bike"]["description"].present?
      if b_param.params["bike"]["description"].present?
        b_param.params["bike"]["description"] += " #{bb_data["bike"]["description"]}"
      else
        b_param.params["bike"]["description"] = bb_data["bike"]["description"]
      end
    end
    b_param.params["bike"]["rear_wheel_bsd"] = bb_data["bike"]["rear_wheel_bsd"] if bb_data["bike"]["rear_wheel_bsd"].present?
    b_param.params["bike"]["rear_tire_narrow"] = bb_data["bike"]["rear_tire_narrow"] if bb_data["bike"]["rear_tire_narrow"].present?
    b_param.params["bike"]["stock_photo_url"] = bb_data["bike"]["stock_photo_url"] if bb_data["bike"]["stock_photo_url"].present?
    b_param.params["components"] = bb_data["components"] && bb_data["components"].map { |c| c.merge("is_stock" => true) }
    b_param.clean_params # if we just rely on the before_save filter, b_param needs to be reloaded
    b_param.save if b_param.id.present?
    b_param
  end

  def clear_bike(bike)
    bike = find_or_build_bike(@b_param)
    bike.errors.messages.each do |message|
      bike.errors.add(message[0], message[1][0])
    end
    bike.ownerships.destroy_all
    bike.bike_organizations.destroy_all
    bike.impound_records.destroy_all
    bike.parking_notifications.destroy_all
    bike.destroy
    bike
  end

  def validate_record(bike)
    return clear_bike(bike) if bike.errors.present?
    @b_param.find_duplicate_bike(bike) if @b_param.no_duplicate?
    if @b_param.created_bike.present?
      clear_bike(bike)
      bike = @b_param.created_bike
    elsif @b_param.id.present? # Only update b_param if it exists
      @b_param.update(created_bike_id: bike.id, bike_errors: nil)
    end
    bike
  end

  def save_bike(bike)
    bike.set_location_info
    bike.save
    ownership = create_ownership(@b_param, bike)
    bike = associate(bike, ownership) unless bike.errors.any?
    validate_record(bike)
    # TODO: part of #2110 - test this based on ownership?
    # We don't want to create an extra creation_state if there was a duplicate.
    # Also - we assume if there is a creation_state, that the bike successfully went through creation
    if bike.present? && bike.id.present?
      AfterBikeSaveWorker.perform_async(bike.id)
      if @b_param.bike_sticker_code.present? && bike.creation_organization.present?
        bike_sticker = BikeSticker.lookup_with_fallback(@b_param.bike_sticker_code, organization_id: bike.creation_organization.id)
        bike_sticker&.claim(user: bike.creator, bike: bike.id, organization: bike.creation_organization)
      end
      if @b_param.unregistered_parking_notification?
        # We skipped setting address, with default_parking_notification_attrs, notification will update it
        ParkingNotification.create!(@b_param.parking_notification_params)
      end
      # Check if the bike has a location, update with passed location if no
      bike.reload
      bike.update(Geohelper.address_hash_from_geocoder_result(@location)) unless bike.latitude.present?
    end
    bike
  end

  def find_or_build_bike(b_param)
    b_param&.created_bike&.present? ? b_param.created_bike : build_bike
  end

  def add_front_wheel_size(bike)
    return bike unless bike.rear_wheel_size_id.present? && bike.front_wheel_size_id.blank?
    bike.front_wheel_size_id = bike.rear_wheel_size_id
    bike.front_tire_narrow = bike.rear_tire_narrow
    bike
  end

  def add_required_attributes(bike)
    bike.propulsion_type ||= "foot-pedal"
    bike.cycle_type ||= "bike"
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

  # previously BikeCreatorOrganizer
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

  def associate(bike, ownership)
    create_parking_notification(@b_param, bike) if @b_param&.status_abandoned?
    create_bike_organizations(ownership)
    ComponentCreator.new(bike: bike, b_param: @b_param).create_components_from_params
    bike.create_normalized_serial_segments
    assign_user_attributes(bike, ownership&.user)
    StolenRecordUpdator.new(bike: bike, b_param: @b_param).update_records
    attach_photo(bike)
    attach_photos(bike)
    bike.save
    bike
  end

  def ownership_creation_attributes(b_param, bike)
    {
      is_new: b_param.is_new,
      pos_kind: b_param.pos_kind,
      origin: b_param.origin,
      status: b_param.status,
      bulk_import_id: b_param.params["bulk_import_id"],
      creator_id: b_param.creator_id,
      can_edit_claimed: bike.creation_organization_id.present?,
      organization_id: bike.creation_organization_id
    }.merge(registration_info: b_param.registration_info_attrs)
  end

  def create_ownership(b_param, bike)
    ownership = bike.ownerships.new(creator: b_param.creator, skip_email: b_param.skip_email?)
    ownership.attributes = ownership_creation_attributes(b_param, bike)
    unless ownership.save
      ownership.errors.messages.each { |msg| bike.errors.add(msg[0], msg[1][0]) }
    end
    ownership
  end

  def create_bike_organizations(ownership)
    organization = ownership.organization
    return true unless organization.present?
    unless BikeOrganization.where(bike_id: ownership.bike_id, organization_id: organization.id).present?
      BikeOrganization.create(bike_id: ownership.bike_id, organization_id: organization.id, can_edit_claimed: ownership.can_edit_claimed)
    end
    if organization.parent_organization.present? && BikeOrganization.where(bike_id: ownership.bike_id, organization_id: organization.parent_organization_id).blank?
      BikeOrganization.create(bike_id: ownership.bike_id, organization_id: organization.parent_organization_id, can_edit_claimed: ownership.can_edit_claimed)
    end
  end

  def create_parking_notification(b_param, bike)
    parking_notification_attrs = b_param.bike.slice("latitude", "longitude", "street", "city", "state_id", "zipcode", "country_id", "accuracy")
    parking_notification_attrs.merge!(kind: b_param.bike["parking_notification_kind"],
      bike_id: bike.id,
      user_id: bike.creator.id,
      organization_id: b_param.creation_organization_id)
    ParkingNotification.create(parking_notification_attrs)
  end

  def assign_user_attributes(bike, user = nil)
    user ||= bike.user
    return true unless user.present?
    if bike.phone.present?
      user.phone = bike.phone if user.phone.blank?
    end
    user.save if user.changed? # Because we're also going to set the address and the name here
    bike
  end

  def attach_photos(bike)
    return nil unless @b_param.params["photos"].present?
    photos = @b_param.params["photos"].uniq.take(7)
    photos.each { |p| PublicImage.create(imageable: bike, remote_image_url: p) }
  end
end
