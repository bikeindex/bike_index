# frozen_string_literal: true

module EmailJobs
  # Only an address has been entered, so the domain check runs first - the same as the
  # register flow's PartialRegistrationJob
  class OrganizationSignupConfirmationJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    def perform(organization_signup_id)
      signup = OrganizationSignup.find_by(id: organization_signup_id)
      # confirm_email! spends the token, so a blank one means there's no link left to send
      return if signup.blank? || signup.email_confirmation_token.blank? || signup.likely_spam

      if EmailDomain::VERIFICATION_ENABLED
        email_domain = EmailDomain.find_or_create_for(signup.email)

        return signup.destroy if email_domain&.banned?
        return if email_domain&.provisional_ban?
      end

      notification = Notification.create(kind: "organization_signup_confirmation", message_channel: "email",
        notifiable: signup, message_channel_target: signup.email)
      Notifications::Deliver.track_email(notification) { OrganizedMailer.organization_signup_confirmation(signup).deliver_now }
    end
  end
end
