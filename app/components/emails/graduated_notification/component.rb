# frozen_string_literal: true

module Emails
  module GraduatedNotification
    class Component < ApplicationComponent
      def initialize(graduated_notification:, bike: nil, email_preview: false, versioned: true)
        @graduated_notification = graduated_notification
        @bike = bike
        @email_preview = email_preview
        @versioned = versioned
      end

      def email_sent_at
        @graduated_notification.sent_at
      end

      def snippet_time
        email_sent_at if @versioned
      end

      private

      def organization
        @graduated_notification.organization
      end

      def bike
        @bike || @graduated_notification.bike
      end

      def organization_snippet_body
        MailSnippet.for_organization(organization_id: organization.id, kind: "graduated_notification", time: snippet_time)&.body
      end

      def tokenized_url
        @email_preview ? OrgServices::EmailPreview::TOKEN_PATH : OrgServices::Displayer.retrieval_link_url(@graduated_notification)
      end
    end
  end
end
