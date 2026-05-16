# frozen_string_literal: true

module Emails
  module GraduatedNotification
    class Component < ApplicationComponent
      def initialize(graduated_notification:, bike: nil, email_preview: false)
        @graduated_notification = graduated_notification
        @bike = bike
        @email_preview = email_preview
      end

      def email_sent_at
        @graduated_notification.sent_at
      end

      private

      def organization
        @graduated_notification.organization
      end

      def bike
        @bike || @graduated_notification.bike
      end

      def organization_snippet_body
        MailSnippet.for_organization(organization_id: organization.id, kind: "graduated_notification", time: email_sent_at)&.body
      end

      def tokenized_url
        @email_preview ? OrganizedServices::EmailPreview::TOKEN_PATH : helpers.retrieval_link_url(@graduated_notification)
      end
    end
  end
end
