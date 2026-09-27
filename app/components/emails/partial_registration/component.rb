# frozen_string_literal: true

module Emails
  module PartialRegistration
    class Component < ApplicationComponent
      def initialize(b_param:, email_preview: false, versioned: true)
        @b_param = b_param
        @email_preview = email_preview
        @versioned = versioned
      end

      def email_sent_at
        @b_param&.created_at if @b_param&.persisted?
      end

      def snippet_time
        email_sent_at if @versioned
      end

      private

      def organization
        @b_param.creation_organization
      end

      def tokenized_url
        return OrgServices::EmailPreview::TOKEN_PATH if @email_preview

        return new_bike_url(b_param_token: @b_param.id_token) unless @b_param.register_flow?

        # Separate attestation's link signs the owner in, since the member is who started it
        token = @b_param.email_confirmation_token if rules_owed?
        return register_url(b_param_token: @b_param.id_token) if token.blank?

        confirm_register_url(b_param_token: @b_param.id_token, confirmation_token: token)
      end

      # defined?, since false is the common answer - each ask is a query
      def rules_owed?
        return @rules_owed if defined?(@rules_owed)

        @rules_owed = @b_param.acknowledgment_pending?
      end

      def organization_snippet_body
        organization&.mail_snippet_body("partial_registration", time: snippet_time)
      end
    end
  end
end
