# frozen_string_literal: true

module Org
  module MenuItems
    class Component < ApplicationComponent
      def initialize(organization:, current_user:, is_dropdown: false, unregistered_parking_notification: nil)
        @organization = organization
        @current_user = current_user
        @is_dropdown = is_dropdown
        @unregistered_parking_notification = unregistered_parking_notification
      end

      def render?
        @organization.present?
      end

      private

      def items
        @items ||= compose_items
      end

      def compose_items
        cached = OrganizedServices::UserMenuItems.for(organization: @organization, current_user: @current_user)
        items = with_route_overrides(cached).reject { |item| skip?(item) }
        items += [divider] if trailing_divider?
        items += [super_admin_link] if @current_user&.superuser?
        items
      end

      def trailing_divider?
        return false if @organization.ambassador?
        !@is_dropdown || @current_user&.superuser?
      end

      def super_admin_link
        {type: :super_admin_link,
         label: I18n.t("shared.organized_menu_items.super_admin_view", org_name: @organization.short_name),
         path: helpers.admin_organization_path(@organization)}
      end

      # Re-add the dashboard / bulk-imports link when the user is on those pages
      # but the org doesn't have the feature enabled — so the active page stays
      # represented in the menu. Cached payload only contains these when the
      # org-level flag is on.
      def with_route_overrides(items)
        items = [dashboard_link, divider, *items] if needs_dashboard_override?(items)
        items = insert_after_add_bike(items, bulk_import_link) if needs_bulk_import_override?(items)
        items
      end

      def needs_dashboard_override?(items)
        on_dashboard? && items.none? { |i| i[:type] == :link && i[:path] == dashboard_link[:path] }
      end

      def needs_bulk_import_override?(items)
        on_bulk_imports? && items.none? { |i| i[:type] == :link && i[:path] == bulk_import_link[:path] }
      end

      # Mirrors the old template: a divider is rendered before the bulk-import
      # link, even though the cached payload already has the unconditional
      # divider that closes the add-bike section after our injection.
      def insert_after_add_bike(items, item)
        index = items.index { |i| i[:active] == :on_bikes_new }
        return items + [divider, item] unless index
        items.dup.insert(index + 1, divider, item)
      end

      def dashboard_link
        @dashboard_link ||= OrganizedServices::UserMenuItems.dashboard_link(@organization)
      end

      def bulk_import_link
        @bulk_import_link ||= OrganizedServices::UserMenuItems.bulk_import_link(@organization)
      end

      def divider
        {type: :divider}
      end

      # Use request.path_parameters rather than controller.controller_name so the
      # routed controller is reflected in component specs (which dispatch through
      # a generic vc_test_controller).
      def routed_controller
        controller.request.path_parameters[:controller]
      end

      def routed_action
        controller.request.path_parameters[:action]
      end

      def on_dashboard?
        routed_controller == "organized/dashboard" && routed_action == "index"
      end

      def on_bulk_imports?
        routed_controller == "organized/bulk_imports"
      end

      def skip?(item)
        @is_dropdown && item[:type] == :disabled
      end

      def link_classes(item, active)
        classes = ["nav-link"]
        classes << "secondary-item" if item[:secondary]
        classes << "active" if active
        classes.join(" ")
      end

      def disabled_classes(item)
        item[:secondary] ? "disabled-menu-item menu-item secondary-item" : "disabled-menu-item menu-item"
      end

      # Resolves the per-request active state for items the cache marked with a symbol.
      # Returns true/false for explicit cases, nil to defer to the active_link helper.
      def active_state(item)
        case item[:active]
        when :auto, :match_controller then nil
        when :on_registrations_index
          routed_controller == "organized/registrations" && routed_action == "index"
        when :on_bikes_new
          on_bikes_new? && !on_bikes_new_with_parking_notification?
        when :on_bikes_new_with_parking_notification
          on_bikes_new_with_parking_notification?
        else
          item[:active]
        end
      end

      def on_bikes_new?
        routed_controller == "organized/bikes" && routed_action == "new"
      end

      def on_bikes_new_with_parking_notification?
        on_bikes_new? && @unregistered_parking_notification.present?
      end
    end
  end
end
