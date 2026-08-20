# frozen_string_literal: true

module Admin
  module OrganizationTabs
    class Component < ApplicationComponent
      TABS = %i[show edit locations paid_functionality sso invoices custom_layouts].freeze

      # Where each tab sends you to see the organization's own side of it. Nothing in
      # organized covers paid functionality or SSO, so both land on the profile the
      # admin edit tab mirrors
      ORGANIZED_VIEWS = {show: :organization_root_path, edit: :organization_manage_path,
                         locations: :locations_organization_manage_path,
                         paid_functionality: :organization_manage_path, sso: :organization_manage_path,
                         custom_layouts: :organization_emails_path}.freeze

      # active: is passed rather than read off the route because a failed update renders the
      # tab it was submitted from, while the action is still "update"
      def initialize(organization:, active:, subtitle: nil, additional_link: nil)
        raise_if_invalid_value!(:active, active, TABS)

        @organization = organization
        @active = active
        @subtitle = subtitle
        @additional_link = additional_link
      end

      private

      def tabs
        entries = [
          {tab: :show, text: "Show", path: admin_organization_path(@organization)},
          {tab: :edit, text: "Edit", path: edit_admin_organization_path(@organization)},
          {tab: :locations, text: locations_text, path: locations_admin_organization_path(@organization)},
          {tab: :paid_functionality, text: "Edit paid functionality",
           path: paid_functionality_admin_organization_path(@organization)},
          {tab: :sso, text: "SSO", path: sso_admin_organization_path(@organization)},
          {tab: :invoices, text: "Org invoices", path: admin_organization_invoices_path(organization_id: organization_param)}
        ]
        return entries unless helpers.display_dev_info? || @active == :custom_layouts

        entries + [{tab: :custom_layouts, text: "Custom layouts", class_name: "only-dev-visible less-strong",
                    path: admin_organization_custom_layouts_path(organization_id: organization_param)}]
      end

      def link_class(entry)
        ["nav-link", entry[:class_name], ("active" if entry[:tab] == @active)].compact.join(" ")
      end

      def locations_text
        safe_join(["Locations", helpers.number_display(@organization.locations.count)], " ")
      end

      # The invoices tab's own action rather than a view of the organization - except on the
      # page that link would point at
      def new_invoice_link
        return if helpers.action_name == "new"

        link_to "New Invoice", new_admin_organization_invoice_path(organization_id: organization_param),
          class: "nav-link btn btn-success btn-sm mr-2"
      end

      def organization_view_link
        link_to "organization's view", public_send(ORGANIZED_VIEWS[@active], organization_id: organization_param),
          class: "btn btn-outline-info btn-sm nav-link"
      end

      def top_right_link
        (@active == :invoices) ? new_invoice_link : organization_view_link
      end

      def organization_param = @organization.to_param
    end
  end
end
