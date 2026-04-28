# frozen_string_literal: true

module Emails
  module OrganizationInvitation
    class Component < ApplicationComponent
      def initialize(organization_role:, is_new_user: false, email_preview: false)
        @organization_role = organization_role
        @is_new_user = is_new_user
        @email_preview = email_preview
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
        @email_preview ? OrganizedMailer::PREVIEW_TOKEN_URL : new_user_url(email: invited_email)
      end
    end
  end
end
