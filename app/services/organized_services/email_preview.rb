module OrganizedServices
  module EmailPreview
    extend Functionable

    # Placeholder for tokenized URLs in email previews — to make sure preview token links don't work
    TOKEN_PATH = "/404"

    def view_component(kind:, organization:, user:, params:)
      if ParkingNotification.kinds.include?(kind)
        parking_notification = find_or_build_parking_notification(kind:, organization:, user:, params:)
        bike = parking_notification.bike || default_bike(organization:, user:)
        Emails::ParkingNotification::Component.new(parking_notification:, bike:, email_preview: true)
      elsif kind == "graduated_notification"
        graduated_notification = find_or_build_graduated_notification(organization:, user:, params:)
        bike = graduated_notification.bike || default_bike(organization:, user:)
        Emails::GraduatedNotification::Component.new(graduated_notification:, bike:, email_preview: true)
      elsif %w[impound_claim_approved impound_claim_denied].include?(kind)
        Emails::ImpoundClaimApprovedOrDenied::Component.new(
          impound_claim: find_or_build_impound_claim(kind:, organization:, params:)
        )
      elsif kind == "partial_registration"
        b_param = organization.b_params.order(:created_at).last ||
          BParam.new(organization_id: organization.id)
        Emails::PartialRegistration::Component.new(b_param:, email_preview: true)
      else
        bike = (kind == "organization_stolen_message") ? default_stolen_bike(organization:, user:) : default_bike(organization:, user:)
        Emails::FinishedRegistration::Component.new(ownership: bike.current_ownership, bike:, email_preview: true)
      end
    end

    # Returns the time the email was sent, when previewing an already-sent message.
    # Used so the email layout can render header/footer snippets as they were at sent time.
    def email_sent_at(kind:, organization:, params:)
      return nil unless ParkingNotification.kinds.include?(kind) && params[:parking_notification_id].present?

      organization.parking_notifications.find_by(id: params[:parking_notification_id])&.sent_at
    end

    def find_or_build_impound_claim(kind:, organization:, params:)
      status = (kind == "impound_claim_approved") ? "approved" : "denied"
      impound_claims = organization.impound_claims
      impound_claim = impound_claims.find(params[:impound_claim_id]) if params[:impound_claim_id].present?
      impound_claim ||= impound_claims.where(status:).last
      return impound_claim if impound_claim.present?

      organization.impound_records.last&.impound_claims&.build(status:)
    end

    #
    # private below here
    #

    def find_or_build_parking_notification(kind:, organization:, user:, params:)
      parking_notifications = organization.parking_notifications
      parking_notification = parking_notifications.find(params[:parking_notification_id]) if params[:parking_notification_id].present?
      parking_notification ||= parking_notifications.where(kind:).last
      return parking_notification if parking_notification.present?

      parking_notification = parking_notifications.build(
        bike: default_bike(organization:, user:),
        kind:,
        user:,
        created_at: Time.current - 1.hour
      )
      parking_notification.set_location_from_organization
      parking_notification
    end

    def find_or_build_graduated_notification(organization:, user:, params:)
      graduated_notifications = organization.graduated_notifications
      graduated_notification = graduated_notifications.find(params[:graduated_notification_id]) if params[:graduated_notification_id].present?
      graduated_notification ||= graduated_notifications.last
      graduated_notification ||
        GraduatedNotification.new(organization_id: organization.id, bike: default_bike(organization:, user:))
    end

    def default_bike(organization:, user:)
      bike = organization.created_bikes.reorder(:id).last
      bike ||= organization.bikes.reorder(:id).last
      return bike if bike.present?

      bike = Bike.new(id: 42,
        creation_organization: organization,
        owner_email: user.email,
        creator: user,
        manufacturer: Manufacturer.other,
        frame_model: "Example bike",
        primary_frame_color: Color.black)
      ownership = bike.ownerships.build(owner_email: bike.owner_email, creator: user, id: 420)
      bike.current_ownership = ownership
      bike
    end

    def default_stolen_bike(organization:, user:)
      bike = organization.bikes.status_stolen.last
      if bike.blank?
        bike = default_bike(organization:, user:)
        bike.current_stolen_record = StolenRecord.new(date_stolen: Time.current - 1.day)
      end
      if OrganizationStolenMessage.for(organization).is_enabled
        bike.current_stolen_record.organization_stolen_message = OrganizationStolenMessage.for(organization)
      end
      bike
    end

    conceal :find_or_build_parking_notification, :find_or_build_graduated_notification,
      :default_bike, :default_stolen_bike
  end
end
