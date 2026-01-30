# frozen_string_literal: true

class BikeServices::Builder
  class << self
    def include_address_record?(organization = nil, user = nil)
      return false if organization.blank?
      return false if user&.address_set_manually?

      organization.additional_registration_fields.include?("reg_address")
    end

    def build(b_param, new_attrs = nil)
      new_attrs ||= {}
      # Default attributes
      bike = Bike.new(cycle_type: "bike")
      # passed_organization is assigned unless b_param has an organization
      passed_organization = new_attrs.delete(:organization)
      bike.attributes = b_param.safe_bike_attrs(new_attrs)

      bike.address_record&.bike = bike # Kinda gross, but gotta get it both ways!

      # If manufacturer_other is an existing manufacturer, reassign it
      if bike.manufacturer_id == Manufacturer.other.id
        manufacturer = Manufacturer.friendly_find(bike.manufacturer_other)
        if manufacturer.present?
          bike.attributes = {manufacturer_id: manufacturer.id, manufacturer_other: nil}
        end
      end
      # Use bike status because it takes into account new_attrs
      bike.build_new_stolen_record(b_param.stolen_attrs) if bike.status_stolen?
      bike.build_new_impound_record(b_param.impound_attrs) if bike.status_impounded?
      bike = check_organization(b_param, bike)
      bike.creation_organization ||= passed_organization
      bike = check_example(b_param, bike)
      if b_param.unregistered_parking_notification?
        bike.attributes = default_parking_notification_attrs(b_param, bike)
      elsif include_address_record?(bike.creation_organization)
        bike.address_record ||= org_address_record(bike)
      end
      bike.bike_sticker = b_param.bike_sticker_code
      if bike.rear_wheel_size_id.present? && bike.front_wheel_size_id.blank?
        bike.attributes = {front_wheel_size_id: bike.rear_wheel_size_id, front_tire_narrow: bike.rear_tire_narrow}
      end
      bike
    end

    def find_or_build(b_param)
      return b_param.created_bike if b_param&.created_bike&.present?

      bike = build(b_param)
      bike.set_calculated_unassociated_attributes

      if b_param.no_duplicate?
        # If a dupe is found, return that rather than the just built bike
        dupe = BikeServices::OwnerDuplicateFinder.matching(serial: bike.serial_number,
          owner_email: bike.owner_email, manufacturer_id: bike.manufacturer_id).first

        if dupe.present?
          b_param.update(created_bike_id: dupe.id)
          return dupe
        end
      end
      bike
    end

    private

    # previously BikeServices::CreatorOrganizer
    def check_organization(b_param, bike)
      organization_id = b_param.params.dig("creation_organization_id").presence ||
        b_param.params.dig("bike", "creation_organization_id")
      organization = Organization.friendly_find(organization_id)
      if organization.present?
        bike.creation_organization = organization
        # TODO: I believe this can be removed, but verify
        # bike.creation_organization_id = organization.id
        bike.creator_id ||= organization.auto_user_id
      else
        # Since there wasn't a valid organization, blank the organization
        bike.creation_organization_id = nil
      end
      bike
    end

    def check_example(b_param, bike)
      example_org = Organization.example
      bike.creation_organization_id = example_org.id if b_param.params && b_param.params["test"]
      if bike.creation_organization_id.present? && example_org.present?
        bike.example = true if bike.creation_organization_id == example_org.id
      else
        bike.example = false
      end
      bike
    end

    def default_parking_notification_attrs(b_param, bike)
      attrs = {
        skip_status_update: true,
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

    def org_address_record(bike)
      org_address = bike.creation_organization.default_address_record
      return if org_address.blank?

      AddressRecord.new(org_address.attributes
        .slice("city", "region_record_id", "country_id")
        .merge(kind: :ownership, bike:))
    end
  end
end
