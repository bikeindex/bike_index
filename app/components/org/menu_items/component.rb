# frozen_string_literal: true

module Org
  module MenuItems
    class Component < ApplicationComponent
      def initialize(organization:, current_user:, is_dropdown: false)
        @organization = organization
        @current_user = current_user
        @is_dropdown = is_dropdown
      end

      def render?
        @organization.present?
      end

      private

      def items
        @items ||= OrganizedServices::MenuItems.for(organization: @organization, current_user: @current_user)
          .reject { |item| skip?(item) }
      end

      def skip?(item)
        return true if @is_dropdown && item[:type] == :disabled
        @is_dropdown && item[:type] == :trailing_divider && !@current_user&.superuser?
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
        when :auto then nil
        when :on_registrations_index
          controller.controller_name == "registrations" && controller.action_name == "index"
        when :on_bikes_new
          on_bikes_new? && !on_bikes_new_with_parking_notification?
        when :on_bikes_new_with_parking_notification
          on_bikes_new_with_parking_notification?
        else
          item[:active]
        end
      end

      def on_bikes_new?
        controller.controller_name == "bikes" && controller.action_name == "new"
      end

      def on_bikes_new_with_parking_notification?
        on_bikes_new? && controller.instance_variable_get(:@unregistered_parking_notification).present?
      end
    end
  end
end
