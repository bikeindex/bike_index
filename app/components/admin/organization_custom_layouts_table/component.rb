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

      # The three kinds are different records with the same five columns, so they're
      # flattened into rows rather than branched over in the markup
      def rows
        [landing_page_row, stolen_message_row] +
          MailSnippet.organization_snippets.map { |kind, attributes| snippet_row(kind, attributes) }
      end

      def landing_page_row
        {edit_label: "Landing page", edit_path: layout_path("landing_page"),
         preview_label: "landing page preview",
         preview_path: organization_landing_path(organization_id: organization_param),
         content: @organization.organization_landing_page&.body?,
         enabled: LandingPages::ORGANIZATIONS.include?(@organization.slug)}
      end

      def stolen_message_row
        {edit_label: "Organization Stolen Message", edit_path: stolen_message_path,
         preview_label: "preview message", preview_path: stolen_message_path,
         content: organization_stolen_message&.body.present?,
         enabled: organization_stolen_message&.is_enabled}
      end

      def snippet_row(kind, attributes)
        snippet = snippets_by_kind[kind]

        {kind_label: MailSnippet.kind_humanized(kind), edit_label: attributes[:description],
         edit_path: layout_path(kind), preview_label: preview_label(attributes[:emails]),
         preview_path: email_path(kind), preview_prefix: ("All emails" if attributes[:emails] == "all"),
         emails: attributes[:emails], content: snippet&.body.present?, enabled: snippet&.is_enabled}
      end

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
