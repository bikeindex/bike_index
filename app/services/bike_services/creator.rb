# frozen_string_literal: true

class BikeServices::Creator
  # Used to be in Bike - but now it's here. Eventually, we should actually do permitted params handling in here
  # ... and have separate permitted params in bikeupdator
  def self.old_attr_accessible
    (%i[manufacturer_id manufacturer_other serial_number
      serial_normalized made_without_serial extra_registration_number
      creation_organization_id manufacturer year thumb_path name
      current_stolen_record_id abandoned frame_material cycle_type frame_model number_of_seats
      handlebar_type frame_size frame_size_number frame_size_unit
      rear_tire_narrow front_wheel_size_id rear_wheel_size_id front_tire_narrow
      primary_frame_color_id secondary_frame_color_id tertiary_frame_color_id paint_id paint_name
      propulsion_type street zipcode country_id state_id city belt_drive
      coaster_brake rear_gear_type_slug rear_gear_type_id front_gear_type_slug front_gear_type_id description owner_email
      timezone date_stolen receive_notifications phone creator creator_id image
      components_attributes b_param_id embeded embeded_extended example organization_affiliation student_id
      stock_photo_url pdf send_email skip_email listing_order approved_stolen primary_activity_id
      marked_user_hidden marked_user_unhidden b_param_id_token is_for_sale bike_organization_ids] +
      [
        stolen_records_attributes: BikeServices::StolenRecordUpdator.old_attr_accessible,
        impound_records_attributes: permitted_impound_attrs,
        components_attributes: Component.permitted_attributes,
        address_record_attributes: (AddressRecord.permitted_params + [:id])
      ]
    ).freeze
  end

  def self.permitted_impound_attrs
    %w[street city state zipcode country timezone impounded_at_with_timezone display_id impounded_description].freeze
  end

  def initialize(ip_address: nil)
    @ip_address = ip_address
  end

  def create_bike(b_param)
    add_bike_book_data(b_param)
    bike = BikeServices::Builder.find_or_build(b_param)
    # Skip processing if this bike is already created
    return bike if bike.id.present? && bike.id == b_param.created_bike_id

    # There could be errors during the build - or during the save
    bike = save_bike(b_param, bike) if bike.errors.none?
    if bike.errors.any?
      b_param&.update(bike_errors: bike.cleaned_error_messages)
    end
    bike
  end

  # Called from ImageAssociatorJob, so can't be private
  def attach_photo(b_param, bike)
    return true unless b_param.image.present?

    public_image = PublicImage.new(image: b_param.image)
    public_image.imageable = bike
    public_image.save
    b_param.update(image_processed: true)
    bike.reload
  end

  private

  # Previously all of this stuff was public.
  # In an effort to refactor and simplify, anything not accessed outside of this class was explicitly made private (PR#1478)

  def add_bike_book_data(b_param = nil)
    return nil unless b_param&.bike.present? && b_param.manufacturer_id.present?
    return nil unless b_param.bike["frame_model"].present? && b_param.bike["year"].present?

    bb_data = Integrations::BikeBook.new.get_model({
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

  def clear_bike(b_param, bike)
    built_bike = BikeServices::Builder.find_or_build(b_param)
    bike.errors.messages.each do |message|
      built_bike.errors.add(message[0], message[1][0])
    end
    bike.ownerships.destroy_all
    bike.bike_organizations.destroy_all
    bike.impound_records.destroy_all
    bike.parking_notifications.destroy_all
    bike.destroy
    built_bike
  end

  def validate_record(b_param, bike)
    return clear_bike(b_param, bike) if bike.errors.present?

    if b_param.created_bike_id.present? && b_param.created_bike_id != bike.id
      clear_bike(b_param, bike)
      return b_param.created_bike
    elsif b_param.id.present? # Only update b_param if it exists
      b_param.update(created_bike_id: bike.id, bike_errors: nil)
    end
    bike
  end

  def save_bike(b_param, bike)
    # TODO: Figure out why this needs to be called separately, before save. See PR #2848
    # Maybe can be removed in #2922
    bike.attributes = BikeServices::CalculateStoredLocation.location_attrs(bike)
    bike.save
    ownership = create_ownership(b_param, bike)
    bike = associate(b_param, bike, ownership) unless bike.errors.any?
    bike = validate_record(b_param, bike)
    return bike unless bike.present? && bike.id.present?

    # NOTE: spaminess is recalculated in Email::OwnershipInvitationJob as a failsafe
    if SpamEstimator.estimate_bike(bike) > SpamEstimator::MARK_SPAM_PERCENT
      bike.update(likely_spam: true)
    end
    ::Callbacks::AfterBikeSaveJob.perform_async(bike.id)
    if b_param.bike_sticker_code.present? && bike.creation_organization.present?
      bike_sticker = BikeSticker.lookup_with_fallback(b_param.bike_sticker_code, organization_id: bike.creation_organization.id)
      bike_sticker&.claim_if_permitted(user: bike.creator, bike: bike.id,
        organization: bike.creation_organization, creator_kind: "creator_bike_creation")
    end
    # TODO: #2911 -
    # Why was this here? Can it be removed?? it's created in association
    #
    if b_param.unregistered_parking_notification?
      pp "unreged", b_param.parking_notification_params
      # We skipped setting address, with Builder.default_parking_notification_attrs,
      # notification will update it
      ParkingNotification.create!(b_param.parking_notification_params)
    end

    # Check if the bike has a location, update with passed IP location if no
    bike.reload
    if bike.latitude.blank?
      # TODO: #2911 - generate an address_record
      bike.update(GeocodeHelper.assignable_address_hash_for(@ip_address))
    end
    bike
  end

  def associate(b_param, bike, ownership)
    create_parking_notification_if_present(b_param, bike)
    create_bike_organizations(ownership)
    ComponentCreator.new(bike: bike, b_param: b_param).create_components_from_params
    bike.create_normalized_serial_segments
    assign_user_attributes(bike, ownership&.user)
    BikeServices::StolenRecordUpdator.new(bike: bike, b_param: b_param).update_records
    attach_photo(b_param, bike)
    attach_photos(b_param, bike)
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

  def create_parking_notification_if_present(b_param, bike)
    pp bike.status, b_param.status
    # pp bike.address_record, bike.address_hash_legacy, b_param.bike
    return unless bike.status_abandoned? # %w[unregistered_parking_notification status_abandoned].include?(bike.status)

    parking_notification_attrs = bike.address_hash_legacy #b_param.bike.slice("latitude", "longitude", "street", "city", "state_id", "zipcode", "country_id", "accuracy")
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

  def attach_photos(b_param, bike)
    return nil unless b_param.params["photos"].present?

    photos = b_param.params["photos"].uniq.take(7)
    photos.each { |p| PublicImage.create(imageable: bike, remote_image_url: p) }
  end
end
