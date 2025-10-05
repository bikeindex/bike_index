# frozen_string_literal: true

class Email::ImpoundClaimJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 3

  def perform(impound_claim_id)
    impound_claim = ImpoundClaim.find(impound_claim_id)

    email_to_send = calculated_email_to_send(impound_claim)
    return nil if email_to_send.blank?

    notification = Notification.create(kind: "impound_claim_#{email_to_send}",
      notifiable: impound_claim,
      bike_id: impound_claim.bike_claimed_id)

    notification.track_email_delivery do
      if email_to_send == "submitting"
        OrganizedMailer.impound_claim_submitted(impound_claim).deliver_now
      else
        OrganizedMailer.impound_claim_approved_or_denied(impound_claim).deliver_now
      end
    end

    ::Callbacks::AfterUserChangeJob.perform_async(impound_claim.user_id)
  end

  def calculated_email_to_send(impound_claim)
    if %w[submitting approved denied].include?(impound_claim.status) &&
        impound_claim.notifications.where(kind: "impound_claim_#{impound_claim.status}").none?
      impound_claim.status
    end
  end
end
