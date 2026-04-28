# frozen_string_literal: true

module Emails
  module GraduatedNotification
    class Component < ApplicationComponent
      def initialize(graduated_notification:, bike: nil, email_preview: false, email_preview_tokenized_url: nil)
        @graduated_notification = graduated_notification
        @bike = bike
        @email_preview = email_preview
        @email_preview_tokenized_url = email_preview_tokenized_url
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
        @email_preview ? @email_preview_tokenized_url : helpers.retrieval_link_url(@graduated_notification)
      end
    end
  end
end
