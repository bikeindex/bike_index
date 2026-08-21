# frozen_string_literal: true

module Admin
  module OrganizationTabs
    class Component < ApplicationComponent
      TABS = %i[show edit locations paid_functionality sso invoices custom_layouts].freeze

      # paid_functionality and sso have no organized page of their own, so both land on the
      # profile the edit tab mirrors
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
        [[:show, "Show", admin_organization_path(@organization)],
          [:edit, "Edit", edit_admin_organization_path(@organization)],
          [:locations, "Locations", edit_admin_organization_path(@organization, tab: "locations"),
            @organization.locations.size],
          [:paid_functionality, "Edit paid functionality", edit_admin_organization_path(@organization, tab: "paid_functionality")],
          ([:sso, "SSO", edit_admin_organization_path(@organization, tab: "sso")] if sso?),
          [:invoices, "Invoices", admin_organization_invoices_path(organization_id: @organization)],
          ([:custom_layouts, "Custom layouts", admin_organization_custom_layouts_path(organization_id: @organization)] if custom_layouts?)]
          .compact.map { |tab, label, href, count| {label:, href:, count:, active: @active == tab} }
      end

      # A tab with nothing behind it is dropped - except on its own page, which still
      # renders (saying the feature is off) and shouldn't lose its place in the row
      def sso? = @organization.enabled?("saml_sso") || @active == :sso

      def custom_layouts? = helpers.display_dev_info? || @active == :custom_layouts

      def new_invoice_link
        path = new_admin_organization_invoice_path(organization_id: @organization)
        return if helpers.current_page_active?(path)

        render(UI::ButtonLink::Component.new(text: "New Invoice", href: path, color: :primary, size: :sm))
      end

      def organization_view_link
        render(UI::ButtonLink::Component.new(text: "organization's view", size: :sm,
          href: public_send(ORGANIZED_VIEWS[@active], organization_id: @organization)))
      end

      def top_right_links
        [@additional_link, (@active == :invoices) ? new_invoice_link : organization_view_link].compact
      end
    end
  end
end
