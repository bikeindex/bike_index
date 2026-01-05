# frozen_string_literal: true

class BikeServices::OwnershipTransferer
  class << self
    def registration_info_from_params(params)
      params.dig("bike")&.slice(*BParam::REGISTRATION_INFO_ATTRS) || {}
    end

    # Returns new_ownership, or nil if no new ownership created
    # DOES NOT authorize
    def create_if_changed(
      bike,
      updator:,
      new_owner_email: nil,
      doorkeeper_app_id: nil,
      registration_info: {},
      processing_impound_record_id: nil,
      skip_save: false,
      skip_email: false
    )
      new_owner_email = EmailNormalizer.normalize(new_owner_email)
      return if new_owner_email.blank? || bike.owner_email == new_owner_email

      # ProcessImpoundUpdatesJob creates ownership transfers, so if a user transferred a was
      # if bike.current_impound_record.present? && processing_impound_record_id.blank?
      #   return create_impound_update(bike, new_owner_email)
      # end
      impound_record_id = processing_impound_record_id || bike.current_impound_record_id
      bike.attributes = updated_bike_attrs(new_owner_email, updator)
      pp updated_bike_attrs(new_owner_email, updator)

      # even if skip_save, still update if an active parking_notification or impound_record
      if bike.current_parking_notification.present? || bike.current_impound_record.present?
        update_impound_and_parking_notifications(bike, updator) unless processing_impound_record_id.present?

        bike.status = "status_with_owner"
        pp bike.save!
        pp "****** - #{bike.id} - #{bike.owner_email} "
        pp bike.reload.owner_email

        # status = "status_with_owner" # bike should be updated
        bike.reload
      elsif !skip_save
        bike.save
      end

      # If updator is a member of the creation organization, add org to the new ownership!
      ownership_org = bike.current_ownership&.organization

      bike.ownerships.create(owner_email: new_owner_email,
        creator: updator,
        origin: "transferred_ownership",
        organization: updator&.member_of?(ownership_org) ? ownership_org : nil,
        # status:,
        registration_info:,
        doorkeeper_app_id:,
        impound_record_id:,
        skip_email:)
    end

    private

    def updated_bike_attrs(owner_email, updator)
      BikeServices::Updator.updator_attrs(updator).merge(
        owner_email:,
        delete_address_record: true,
        is_phone: false, # TODO: base on new ownership, but phone regs aren't being used
        marked_user_unhidden: true,
        is_for_sale: false)
    end

    def update_impound_and_parking_notifications(bike, updator)
      if bike.current_impound_record.present?
        # NOTE: ProcessImpoundUpdatesJob will call create_if_changed - but, since the email will be the same,
        # it's a no-op
        pp "> #{bike.owner_email}"
        bike.current_impound_record.impound_record_updates.create(
            kind: :transferred_to_new_owner,
            user_id: updator.id,
            transfer_email: bike.owner_email
          )

        # impound records resolve parking notifications (if both are present)
      elsif bike.current_parking_notification.present?
        pp "parking notification!"
      end
    end
  end
end
