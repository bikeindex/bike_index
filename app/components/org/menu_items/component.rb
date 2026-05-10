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
        @items ||= OrganizedServices::MenuItems.for(
          organization: @organization,
          current_user: @current_user,
          controller_name: controller.controller_name,
          action_name: controller.action_name,
          unregistered_parking_notification: controller.instance_variable_get(:@unregistered_parking_notification),
          is_dropdown: @is_dropdown
        )
      end

      def link_classes(item)
        classes = ["nav-link"]
        classes << "secondary-item" if item[:secondary]
        classes << "active" if item[:active] == true
        classes.join(" ")
      end

      def disabled_classes(item)
        item[:secondary] ? "disabled-menu-item menu-item secondary-item" : "disabled-menu-item menu-item"
      end
    end
  end
end
