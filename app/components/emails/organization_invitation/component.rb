# frozen_string_literal: true

module Emails
  module OrganizationInvitation
    class Component < ApplicationComponent
      def initialize(organization_role:, is_new_user: false, email_preview: false, email_preview_tokenized_url: nil)
        @organization_role = organization_role
        @is_new_user = is_new_user
        @email_preview = email_preview
        @email_preview_tokenized_url = email_preview_tokenized_url
      end

      private

      def organization
        @organization_role.organization
      end

      def sender
        @organization_role.sender
      end

      def invited_email
        @organization_role.invited_email
      end

      def tokenized_url
        @email_preview ? @email_preview_tokenized_url : new_user_url(email: invited_email)
      end
    end
  end
end
