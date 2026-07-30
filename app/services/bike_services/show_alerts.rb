# frozen_string_literal: true

module BikeServices
  # The token-scoped prompts shown above a registration: the claim invitation, a
  # parking/graduated notification's resolve form, and the recovery form. These are
  # per-request rather than per-bike, so Registrations::Show::Wrapper folds
  # Resolved#cache_key into its fragment key — otherwise one viewer's prompt would
  # be cached and served to everyone.
  module ShowAlerts
    extend Functionable

    Resolved = Data.define(:claim_message, :token, :token_type, :matching_notification, :recovered_stolen_record)

    # recovery_link_token is read from the session by the caller (which deletes it,
    # so the prompt shows once); the token params arrive on the query string and
    # survive the bikes#show redirect to the redesign.
    def find(bike:, params:, recovery_link_token: nil)
      token = params[:parking_notification_retrieved].presence || params[:graduated_notification_remaining].presence
      notification, token_type = notification_for(bike:, params:, token:)

      Resolved.new(claim_message: claim_message_for(bike:, claim_token: params[:t]),
        token:, token_type:, matching_notification: notification,
        recovered_stolen_record: recovered_stolen_record_for(bike:, recovery_link_token:))
    end

    #
    # private below here
    #

    def claim_message_for(bike:, claim_token:)
      ownership = bike.current_ownership
      return if ownership.blank? || !secure_compare?(claim_token, ownership.token)

      ownership.claim_message
    end

    def notification_for(bike:, params:, token:)
      return [nil, nil] if token.blank?

      if params[:parking_notification_retrieved].present?
        notification = bike.parking_notifications.where(retrieval_link_token: token).first
        [notification, notification&.kind || "parked_incorrectly_notification"]
      else
        [GraduatedNotification.where(bike_id: bike.id, marked_remaining_link_token: token).first,
          "graduated_notification"]
      end
    end

    # Only offered while the bike is still stolen — a recovered one has nothing to mark
    def recovered_stolen_record_for(bike:, recovery_link_token:)
      return unless bike.status_stolen?

      StolenRecord.find_matching_token(bike_id: bike.id, recovery_link_token:)
    end

    def secure_compare?(value, expected)
      expected.present? && ActiveSupport::SecurityUtils.secure_compare(value.to_s, expected)
    end

    conceal :claim_message_for, :notification_for, :recovered_stolen_record_for, :secure_compare?
  end
end
