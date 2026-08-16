# frozen_string_literal: true

module Org
  module MenuItems
    class Component < ApplicationComponent
      BIKES_NEW_ROUTE = "organized/bikes#new"
      ACTIVE_ROUTES = {on_registrations_index: "organized/registrations#index",
                       on_registration_sequences: "organized/registration_sequences " \
                         "organized/registration_sequence_pages"}.freeze
      private_constant :BIKES_NEW_ROUTE, :ACTIVE_ROUTES

      # The pages with_route_overrides injects a link for. The navbar folds this into its
      # cache key, so a dropdown cached on one page can't carry another's override.
      def self.route_override_key(controller_namespace:, controller_name:, action_name:)
        return nil unless controller_namespace == "organized"

        case controller_name
        when "dashboard" then ("dashboard" if action_name == "index")
        when "bulk_imports" then "bulk_imports"
        when "registration_sequences", "registration_sequence_pages" then "registration_sequences"
        end
      end

      def initialize(organization:, current_user:, controller_namespace:, controller_name:, action_name:,
        is_dropdown: false, unregistered_parking_notification: nil)
        @organization = organization
        @current_user = current_user
        @controller_namespace = controller_namespace
        @controller_name = controller_name
        @action_name = action_name
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

      # Re-add a feature-gated link when the user is on its page but the org
      # doesn't have the feature enabled — so the active page stays represented
      # in the menu. The cached payload only contains these when the org-level
      # flag is on.
      def with_route_overrides(items)
        items = [dashboard_link, divider, *items] if needs_dashboard_override?(items)
        items = insert_after_add_bike(items, bulk_import_link) if needs_bulk_import_override?(items)
        items += [registration_sequences_link] if needs_registration_sequences_override?(items)
        items
      end

      def needs_dashboard_override?(items)
        on_dashboard? && items.none? { |i| i[:type] == :link && i[:path] == dashboard_link[:path] }
      end

      def needs_bulk_import_override?(items)
        on_bulk_imports? && items.none? { |i| i[:type] == :link && i[:path] == bulk_import_link[:path] }
      end

      def needs_registration_sequences_override?(items)
        on_registration_sequences? && items.none? { |i| i[:type] == :link && i[:path] == registration_sequences_link[:path] }
      end

      # Always emits a divider above `item` so the injected link is visually
      # separated from the add-bike row, regardless of what's already in `items`.
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

      def registration_sequences_link
        @registration_sequences_link ||= OrganizedServices::UserMenuItems.registration_sequences_link(@organization)
      end

      def divider
        {type: :divider}
      end

      def organized_controller?(*controller_names)
        @controller_namespace == "organized" && controller_names.include?(@controller_name)
      end

      def route_override_key
        return @route_override_key if defined?(@route_override_key)

        @route_override_key = self.class.route_override_key(controller_namespace: @controller_namespace,
          controller_name: @controller_name, action_name: @action_name)
      end

      def on_dashboard?
        route_override_key == "dashboard"
      end

      def on_bulk_imports?
        route_override_key == "bulk_imports"
      end

      def on_registration_sequences?
        route_override_key == "registration_sequences"
      end

      def skip?(item)
        @is_dropdown && item[:type] == :disabled
      end

      # The dropdown renders inside the navbar's page-agnostic cache, so it ships the rule
      # to page-block--navbar; the sidebar renders per request and resolves it here
      def link_tag(item)
        return link_to(item[:label], item[:path], class: link_classes(item, false), data: active_data(item)) if
          @is_dropdown

        active = active_state(item)
        return link_to(item[:label], item[:path], class: link_classes(item, active)) unless active.nil?

        helpers.active_link(item[:label], item[:path], class: link_classes(item, false),
          match_controller: item[:active] == :match_controller)
      end

      def active_data(item)
        return {active_path: true} if item[:active] == :auto

        routes = active_routes(item)
        routes.present? ? {active_routes: routes} : {}
      end

      # Both add-bike links route to organized/bikes#new — which of them can be active comes
      # from the parking notification, which the navbar's cache key already covers
      def active_routes(item)
        case item[:active]
        when :match_controller then NavRoute.controller_for(item[:path])
        when :on_bikes_new then BIKES_NEW_ROUTE unless @unregistered_parking_notification
        when :on_bikes_new_with_parking_notification then BIKES_NEW_ROUTE if @unregistered_parking_notification
        else ACTIVE_ROUTES[item[:active]]
        end
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
          organized_controller?("registrations") && @action_name == "index"
        when :on_bikes_new
          on_bikes_new? && !on_bikes_new_with_parking_notification?
        when :on_bikes_new_with_parking_notification
          on_bikes_new_with_parking_notification?
        when :on_registration_sequences
          on_registration_sequences?
        else
          item[:active]
        end
      end

      def on_bikes_new?
        organized_controller?("bikes") && @action_name == "new"
      end

      def on_bikes_new_with_parking_notification?
        on_bikes_new? && @unregistered_parking_notification.present?
      end
    end
  end
end
