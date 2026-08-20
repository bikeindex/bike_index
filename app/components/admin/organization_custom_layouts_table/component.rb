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

      # OrganizationStolenMessage.for creates the message, so it runs once and only for an
      # organization with the feature - reading this page shouldn't bring one into being
      def organization_stolen_message
        return @organization_stolen_message if defined?(@organization_stolen_message)

        @organization_stolen_message = if @organization.enabled?("organization_stolen_message")
          OrganizationStolenMessage.for(@organization)
        else
          @organization.organization_stolen_message
        end
      end

      def stolen_message_path
        edit_organization_email_path("organization_stolen_message", organization_id: organization_param)
      end

      def layout_path(id) = edit_admin_organization_custom_layout_path(organization_id: organization_param, id:)

      def email_path(kind) = edit_organization_email_path(kind, organization_id: organization_param)

      def snippet_for(kind) = snippets_by_kind[kind]

      def snippets_by_kind = @snippets_by_kind ||= @organization.mail_snippets.index_by(&:kind)

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
