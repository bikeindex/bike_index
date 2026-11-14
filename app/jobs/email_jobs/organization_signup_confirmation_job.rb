# frozen_string_literal: true

module EmailJobs
  class OrganizationSignupConfirmationJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    def perform(organization_signup_id)
      signup = OrganizationSignup.find_by(id: organization_signup_id)
      # confirm_email! spends the token, so a blank one means there's no link left to send
      return if signup.blank? || signup.email_confirmation_token.blank? || signup.likely_spam

      Notifications::Deliver.track_unproven_email(signup, email: signup.email, kind: "organization_signup_confirmation",
        message_channel_target: signup.email) { OrganizedMailer.organization_signup_confirmation(signup).deliver_now }
    end
  end
end
