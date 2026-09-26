# frozen_string_literal: true

module Emails
  module OrganizationMessage
    class Component < ApplicationComponent
      def initialize(organization_message:)
        @organization_message = organization_message
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
    end
  end
end
