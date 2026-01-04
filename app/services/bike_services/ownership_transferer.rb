# frozen_string_literal: true

class BikeServices::OwnershipTransferer
  class << self
    def registration_info_from_params(params)
      params.dig("bike")&.slice(*BParam::REGISTRATION_INFO_ATTRS) || {}
    end

    # Returns new_ownership, or nil if no new ownership created
    # DOES NOT authorize
    def create_if_changed(bike, updator:, new_owner_email: nil, doorkeeper_app_id: nil, registration_info: {},
      skip_save: false, skip_email: false)
      # ^

      new_owner_email = EmailNormalizer.normalize(new_owner_email)
      return if new_owner_email.blank? || bike.owner_email == new_owner_email

      # Since we've deleted the owner_email from the update hash, we have to assign it here
      bike.owner_email = new_owner_email
      bike.attributes = BikeServices::Updator.updator_attrs(updator)

      # even if skip_save, still update if an abandoned bike
      if %w[unregistered_parking_notification status_abandoned status_impounded].include?(bike.status)
        bike.update(status: "status_with_owner", marked_user_unhidden: true)
        status = "status_with_owner"
      elsif !skip_save
        bike.save
      end
      # If updator is a member of the creation organization, add org to the new ownership!
      ownership_org = bike.current_ownership&.organization

      bike.ownerships.create(owner_email: new_owner_email,
        creator: updator,
        origin: "transferred_ownership",
        organization: updator&.member_of?(ownership_org) ? ownership_org : nil,
        status:,
        registration_info:,
        doorkeeper_app_id:,
        skip_email:)
    end
  end
end
