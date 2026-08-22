# frozen_string_literal: true

module Admin
  module Organizations
    module Tabs
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
        def initialize(organization:, active:, subtitle: nil, additional_link: nil, turbo: true,
          display_dev_info: false)
          raise_if_invalid_value!(:active, active, TABS)

          @organization = organization
          @active = active
          @subtitle = subtitle
          @additional_link = additional_link
          @turbo = turbo
          @display_dev_info = display_dev_info
        end

        private

        def tabs
          [ComponentStructs::Shapes.tab("Show", admin_organization_path(@organization), tab: :show),
            ComponentStructs::Shapes.tab("Edit", edit_tab_path, tab: :edit),
            ComponentStructs::Shapes.tab("Locations", edit_tab_path(:locations),
              count: @organization.locations.size, tab: :locations),
            ComponentStructs::Shapes.tab("Edit paid functionality", edit_tab_path(:paid_functionality),
              tab: :paid_functionality),
            ComponentStructs::Shapes.tab("SSO", edit_tab_path(:sso), tab: :sso),
            ComponentStructs::Shapes.tab("Invoices", admin_organization_invoices_path(organization_id: @organization),
              tab: :invoices),
            ComponentStructs::Shapes.tab("Custom layouts",
              admin_organization_custom_layouts_path(organization_id: @organization),
              classes: "only-dev-visible", tab: :custom_layouts)]
            .select { render_tab?(it[:tab]) }
            .map { it.except(:tab).merge(active: @active == it[:tab]) }
        end

        def edit_tab_path(tab = nil) = edit_admin_organization_path(@organization, tab:)

        # A tab with nothing behind it is dropped - except on its own page, which still
        # renders (saying so) and shouldn't lose its place in the row
        def render_tab?(tab)
          return true if @active == tab

          case tab
          when :paid_functionality then @organization.paid?
          when :sso then @organization.enabled?("saml_sso")
          # Not "nothing behind it" - the page is developer-only, so its tab follows dev info
          when :custom_layouts then @display_dev_info
          else true
          end
        end

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
end
