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

        @b_param.register_flow? ? register_url(b_param_token: @b_param.id_token) : new_bike_url(b_param_token: @b_param.id_token)
      end

      # The bike exists, held on the organization's safety rules - which the owner is sent
      # to agree to when the separate attestation switch left them out
      def rules_owed? = @b_param.acknowledgment_pending?

      def organization_snippet_body
        organization&.mail_snippet_body("partial_registration", time: snippet_time)
      end
    end
  end
end
