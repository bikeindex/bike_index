# frozen_string_literal: true

module Emails
  module OrganizationSignupConfirmation
    class Component < ApplicationComponent
      def initialize(organization_signup:)
        @organization_signup = organization_signup
      end

      private

      def expiration_days
        OrganizationSignup::TOKEN_EXPIRATION.in_days.to_i
      end

      def tokenized_url
        confirm_organization_signup_url(signup_token: @organization_signup.id_token,
          confirmation_token: @organization_signup.email_confirmation_token)
      end
    end
  end
end
