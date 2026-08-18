# frozen_string_literal: true

module Org
  module MenuItems
    class Component < ApplicationComponent
      # The cache marks these for UI::ActiveLink to resolve per request, at these granularities
      MATCHES = UI::ActiveLink::Component.match_table(auto: :path, match_controller: :controller,
        on_registrations_index: :controller_action)

      def initialize(organization:, current_user:, controller_namespace:, controller_name:, action_name:,
        is_dropdown: false, unregistered_parking_notification: nil, old_register_view: false,
        register_flow_organization_id: nil)
        @organization = organization
        @current_user = current_user
        @controller_namespace = controller_namespace
        @controller_name = controller_name
        @action_name = action_name
        @is_dropdown = is_dropdown
        @unregistered_parking_notification = unregistered_parking_notification
        @old_register_view = old_register_view
        @register_flow_organization_id = register_flow_organization_id
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
        items = with_old_register_view(items) if @old_register_view
        items
      end

      # Whoever went back to the embed form keeps being sent there, until they take the
      # register flow's link the other way
      def with_old_register_view(items)
        items.map do |item|
          next item unless item[:active] == :on_bikes_new

          item.merge(path: helpers.new_organization_bike_path(organization_id: @organization.to_param))
        end
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

      def on_dashboard?
        organized_controller?("dashboard") && @action_name == "index"
      end

      def on_bulk_imports?
        organized_controller?("bulk_imports")
      end

      def on_registration_sequences?
        organized_controller?("registration_sequences", "registration_sequence_pages")
      end

      def skip?(item)
        @is_dropdown && item[:type] == :disabled
      end

      def link_classes(item)
        classes = ["nav-link"]
        classes << "secondary-item" if item[:secondary]
        classes.join(" ")
      end

      def disabled_classes(item)
        item[:secondary] ? "disabled-menu-item menu-item secondary-item" : "disabled-menu-item menu-item"
      end

      # Resolves the per-request active state for items the cache marked with a symbol.
      # Returns true/false for explicit cases, nil to defer to UI::ActiveLink.
      def active_state(item)
        return nil if MATCHES.key?(item[:active])

        case item[:active]
        when :on_bikes_new
          # The register flow links back to the old form, so its row highlights on both
          on_registrations_new? || on_register_flow? ||
            (on_bikes_new? && !on_bikes_new_with_parking_notification?)
        when :on_bikes_new_with_parking_notification
          on_bikes_new_with_parking_notification?
        when :on_registration_sequences
          on_registration_sequences?
        else
          item[:active]
        end
      end

      # The flow's later steps are on /register, which no organized route matches
      def on_register_flow?
        @register_flow_organization_id == @organization.id
      end

      def on_registrations_new?
        organized_controller?("registrations") && @action_name == "new"
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
