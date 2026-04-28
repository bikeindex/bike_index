# frozen_string_literal: true

module Emails
  module GraduatedNotification
    class Component < ApplicationComponent
      def initialize(graduated_notification:, bike: nil, email_preview: false)
        @graduated_notification = graduated_notification
        @bike = bike
        @email_preview = email_preview
      end

      private

      def organization
        @graduated_notification.organization
      end

      def bike
        @bike || @graduated_notification.bike
      end

      def organization_snippet_body
        organization.mail_snippets.enabled.graduated_notification.first&.body
      end

      def tokenized_url
        @email_preview ? EMAIL_PREVIEW_URL : helpers.retrieval_link_url(@graduated_notification)
      end
    end
  end
end
