# frozen_string_literal: true

module BikeServices
  # The token-scoped prompts shown above a registration: the claim invitation, a
  # parking/graduated notification's resolve form, and the recovery form
  module ShowCurrentAlerts
    extend Functionable

    # The caller reads recovery_link_token from the session, deleting it so the prompt
    # shows once. The rest arrive as query params, and survive the bikes#show redirect
    def find(bike:, params:, recovery_link_token: nil)
      token, token_type, matching_notification = notification_for(bike:, params:)

      {claim_message: claim_message_for(bike:, claim_token: params[:t]),
       token:, token_type:, matching_notification:,
       recovered_stolen_record: recovered_stolen_record_for(bike:, recovery_link_token:)}
    end

    #
    # private below here
    #

    def claim_message_for(bike:, claim_token:)
      ownership = bike.current_ownership
      return if ownership.blank? || !Binxtils::Secure.compare?(claim_token, ownership.token)

      ownership.claim_message
    end

    # [token, token_type, notification] — each branch owns the param it reads
    def notification_for(bike:, params:)
      if (token = params[:parking_notification_retrieved].presence)
        notification = bike.parking_notifications.find_by(retrieval_link_token: token)
        [token, notification&.kind || "parked_incorrectly_notification", notification]
      elsif (token = params[:graduated_notification_remaining].presence)
        [token, "graduated_notification",
          GraduatedNotification.find_by(bike_id: bike.id, marked_remaining_link_token: token)]
      else
        [nil, nil, nil]
      end
    end

    # Only offered while the bike is still stolen — a recovered one has nothing to mark
    def recovered_stolen_record_for(bike:, recovery_link_token:)
      return unless bike.status_stolen?

      StolenRecord.find_matching_token(bike_id: bike.id, recovery_link_token:)
    end

    conceal :claim_message_for, :notification_for, :recovered_stolen_record_for
  end
end
