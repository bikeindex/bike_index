# frozen_string_literal: true

module Emails
  module OrganizationMessage
    class Component < ApplicationComponent
      def initialize(organization_message:, versioned: true)
        @organization_message = organization_message
        @versioned = versioned
      end

      def snippet_time
        @organization_message.created_at if @versioned
      end

      private

      def bike
        @organization_message.bike
      end

      def sender_email
        @organization_message.sender.email
      end

      def organization_name
        @organization_message.organization.short_name
      end

      def mail_snippet = @mail_snippet ||= @organization_message.mail_snippet(time: snippet_time)
    end
  end
end
