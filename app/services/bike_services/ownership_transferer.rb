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
      sale_id: nil,
      processing_impound_record_id: nil,
      skip_save: false,
      skip_email: false
    )
      new_owner_email = EmailNormalizer.normalize(new_owner_email)
      return if new_owner_email.blank? || bike.owner_email == new_owner_email

      impound_record_id = processing_impound_record_id || bike.current_impound_record_id
      bike.attributes = updated_bike_attrs(new_owner_email, updator)

      if bike.current_parking_notification.present? || bike.current_impound_record.present?
        update_impound_and_parking_notifications(bike, updator) unless processing_impound_record_id.present?
        bike.status = "status_with_owner"
        # Force saving if an active parking_notification or impound_record
        skip_save = false
      end

      # If updator is a member of the creation organization, add org to the new ownership!
      ownership_org = bike.current_ownership&.organization

      new_ownership = bike.ownerships.create(current: true,
        owner_email: new_owner_email,
        creator: updator,
        origin: processing_impound_record_id.present? ? :impound_process : :transferred_ownership,
        organization: updator&.member_of?(ownership_org) ? ownership_org : nil,
        status: bike.status, # bike.status might be assigned but not saved, it's calculated in ownership
        user_hidden: false,
        registration_info:,
        doorkeeper_app_id:,
        impound_record_id:,
        sale_id:,
        skip_email:)

      bike.save unless skip_save

      new_ownership
    end

    private

    def updated_bike_attrs(owner_email, updator)
      BikeServices::Updator.updator_attrs(updator).merge(
        owner_email:,
        delete_address_record: true,
        is_phone: false, # TODO: base on new ownership, but phone regs aren't being used
        marked_user_unhidden: true,
        is_for_sale: false
      )
    end

    def update_impound_and_parking_notifications(bike, updator)
      if bike.current_impound_record.present?
        # NOTE: ProcessImpoundUpdatesJob will call create_if_changed - but, since the email's the same,
        # it's a no-op
        bike.current_impound_record.impound_record_updates.create(
          kind: :transferred_to_new_owner,
          user_id: updator.id,
          transfer_email: bike.owner_email
        )

      elsif bike.current_parking_notification.present? # impound records resolve parking notifications (if both present)
        bike.current_parking_notification.mark_retrieved!(retrieved_kind: :ownership_transfer,
          retrieved_by_id: updator.id)
      end
    end
  end
end
