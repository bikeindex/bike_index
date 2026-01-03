# frozen_string_literal: true

class BikeServices::OwnershipCreator
  class << self
    def registration_info_from_params(params)
      params.dig("bike")&.slice(*BParam::REGISTRATION_INFO_ATTRS) || {}
    end

    # Returns [bike, new_ownership] (new_ownership can be nil)
    def transfer_if_changed(bike, updator:, new_owner_email: nil, doorkeeper_app_id: nil, registration_info: {}, skip_save: false, skip_email: false)
      return [bike, nil] if new_owner_email.blank? || bike.owner_email == new_owner_email

      # Since we've deleted the owner_email from the update hash, we have to assign it here
      bike.owner_email = new_owner_email
      bike.attributes = BikeServices::Updator.updator_attrs(updator)

      # even if skip_save, still update if an unregistered parking notification
      if bike.unregistered_parking_notification?
        bike.update(status: "status_with_owner", marked_user_unhidden: true)
      elsif !skip_save
        bike.save
      end
      # If updator is a member of the creation organization, add org to the new ownership!
      ownership_org = bike.current_ownership&.organization

      # If previous ownership was with_owner, this should be too. Required for impounding :shrug:
      status = "status_with_owner" if bike.current_ownership&.status_with_owner?

      # registration_info = bike_params["bike"].slice(*BParam::REGISTRATION_INFO_ATTRS) || {}

      new_ownership = bike.ownerships.create(owner_email: new_owner_email,
        creator: updator,
        origin: "transferred_ownership",
        organization: updator&.member_of?(ownership_org) ? ownership_org : nil,
        status:,
        registration_info:,
        doorkeeper_app_id:,
        skip_email:)

      [bike, new_ownership]
    end
  end
end
