# frozen_string_literal: true

class BikeServices::Creator
  PERMITTED_ATTRS = %i[
    abandoned
    approved_stolen
    b_param_id
    b_param_id_token
    belt_drive
    bike_organization_ids
    coaster_brake
    components_attributes
    creation_organization_id
    creator
    creator_id
    current_stolen_record_id
    cycle_type
    date_stolen
    description
    embeded
    embeded_extended
    example
    extra_registration_number
    frame_material
    frame_model
    frame_size
    frame_size_number
    frame_size_unit
    front_gear_type_id
    front_gear_type_slug
    front_tire_narrow
    front_wheel_size_id
    handlebar_type
    image
    is_for_sale
    listing_order
    made_without_serial
    manufacturer
    manufacturer_id
    manufacturer_other
    marked_user_hidden
    marked_user_unhidden
    name
    number_of_seats
    organization_affiliation
    owner_email
    paint_id
    paint_name
    pdf
    phone
    primary_activity_id
    primary_frame_color_id
    propulsion_type
    rear_gear_type_id
    rear_gear_type_slug
    rear_tire_narrow
    rear_wheel_size_id
    receive_notifications
    secondary_frame_color_id
    send_email
    serial_normalized
    serial_number
    skip_email
    stock_photo_url
    student_id
    tertiary_frame_color_id
    thumb_path
    timezone
    year
  ].freeze
  PERMITTED_IMPOUND_ATTRS = [
    :display_id,
    :impounded_at,
    :impounded_at_with_timezone,
    :impounded_description,
    :timezone,
    address_record_attributes: (AddressRecord.permitted_params + [:id, :skip_geocoding])
  ].freeze
  # Used to be in Bike - but now it's here. Eventually, we should actually do permitted params handling in here
  # ... and have separate permitted params in bikeupdator
  def self.old_attr_accessible
    (PERMITTED_ATTRS + [
      stolen_records_attributes: BikeServices::StolenRecordUpdator.old_attr_accessible,
      impound_records_attributes: PERMITTED_IMPOUND_ATTRS,
      components_attributes: Component.permitted_attributes,
      address_record_attributes: AddressRecord.permitted_params
    ]).freeze
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
    bike.save

    ownership = create_ownership(b_param, bike)
    bike = associate(b_param, bike, ownership) unless bike.errors.any?
    bike = validate_record(b_param, bike)
    return bike unless bike.present? && bike.id.present?

    # NOTE: spaminess is recalculated in Email::OwnershipInvitationJob as a failsafe
    if SpamEstimator.estimate_bike(bike) > SpamEstimator::MARK_SPAM_PERCENT
      bike.update(likely_spam: true)
    end
    CallbackJob::AfterBikeSaveJob.perform_async(bike.id)
    if b_param.bike_sticker_code.present? && bike.creation_organization.present?
      bike_sticker = BikeSticker.lookup_with_fallback(b_param.bike_sticker_code, organization_id: bike.creation_organization.id)
      bike_sticker&.claim_if_permitted(user: bike.creator, bike: bike.id,
        organization: bike.creation_organization, creator_kind: "creator_bike_creation")
    end
    # TODO: consolidate into create_parking_notification in #2922
    if b_param.unregistered_parking_notification?
      # We skipped setting address, with Builder.default_parking_notification_attrs,
      # notification will update it
      ParkingNotification.create!(b_param.parking_notification_params)
    end

    bike.reload
  end

  def associate(b_param, bike, ownership)
    create_parking_notification(b_param, bike) if b_param&.status_abandoned?
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
      doorkeeper_app_id: b_param.doorkeeper_app_id,
      bulk_import_id: b_param.params["bulk_import_id"],
      creator_id: b_param.creator_id,
      can_edit_claimed: bike.creation_organization_id.present?,
      organization_id: bike.creation_organization_id,
      address_record_id: bike.address_record_id
    }.merge(registration_info: b_param.registration_info_attrs.merge(ip_address: @ip_address))
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
    parking_notification_attrs = bike.address_hash_legacy
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
