# frozen_string_literal: true

module Admin
  module OrganizationCustomLayoutsTable
    # Every custom layout an organization can have — its landing page, its stolen message,
    # and each mail snippet — with where to edit and preview each.
    class Component < ApplicationComponent
      def initialize(organization:)
        @organization = organization
      end

      private

      def organization_param = @organization.to_param

      # Reading a message that doesn't exist yet shouldn't create one, so only an
      # organization with the feature gets OrganizationStolenMessage.for
      def organization_stolen_message
        return @organization.organization_stolen_message unless @organization.enabled?("organization_stolen_message")

        OrganizationStolenMessage.for(@organization)
      end

      def stolen_message_path
        edit_organization_email_path("organization_stolen_message", organization_id: organization_param)
      end

      def layout_path(id) = edit_admin_organization_custom_layout_path(organization_id: organization_param, id:)

      def email_path(kind) = edit_organization_email_path(kind, organization_id: organization_param)

      def snippet_for(kind) = @organization.mail_snippets.where(kind:).first

      def preview_label(emails)
        case emails
        when "all" then "eg finished registration"
        when "finished_registration" then "preview finished registration"
        when "partial_registration" then "preview partial registration"
        end
      end
    end
  end
end
