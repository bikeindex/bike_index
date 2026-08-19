# frozen_string_literal: true

module Org
  module MenuItems
    class Component < ApplicationComponent
      def initialize(organization:, current_user:, controller_namespace:, controller_name:, action_name:,
        is_dropdown: false, old_register_view: false, register_flow_organization_id: nil)
        @organization = organization
        @current_user = current_user
        @controller_namespace = controller_namespace
        @controller_name = controller_name
        @action_name = action_name
        @is_dropdown = is_dropdown
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
        items = with_add_bike_override(items) if add_bike_override.any?
        items
      end

      # The link's own page is all the browser can match it against, so the flow's later
      # steps - on /register, which no organized route matches - widen it to that
      # controller, and only in the organization being registered for
      def add_bike_override
        return @add_bike_override if defined?(@add_bike_override)

        @add_bike_override = if @old_register_view
          # Whoever went back to the embed form keeps being sent there, until they take
          # the register flow's link the other way
          {path: helpers.new_organization_bike_path(organization_id: @organization.to_param)}
        elsif @register_flow_organization_id == @organization.id
          {match: :controller, matching_controllers: ["register"]}
        else
          {}
        end
      end

      def with_add_bike_override(items)
        items.map do |item|
          (item[:path] == add_bike_link[:path]) ? item.merge(add_bike_override) : item
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
        index = items.index { |i| i[:path] == add_bike_link[:path] }
        return items + [divider, item] unless index
        items.dup.insert(index + 1, divider, item)
      end

      def add_bike_link
        @add_bike_link ||= OrganizedServices::UserMenuItems.add_bike_link(@organization)
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
    end
  end
end
