# frozen_string_literal: true

module UI
  module Dropdown
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants

      # @label default (drop_direction: bottom_end)
      def default
        render(UI::Dropdown::Component.new(name: "Menu")) do |dropdown|
          dropdown.with_entry_item { content_tag(:a, "Profile", href: "#") }
          dropdown.with_entry_item { content_tag(:a, "Settings", href: "#") }
          dropdown.with_entry_divider
          dropdown.with_entry_item { content_tag(:a, "Logout", href: "#") }
        end
      end

      def custom_button
        render(UI::Dropdown::Component.new(
          name: "User",
          button_class: avatar_button_class
        )) do |dropdown|
          dropdown.with_button { avatar_button }
          dropdown.with_entry_item { content_tag(:span, "Last synced: 2 minutes ago", class: "tw:block tw:px-4 tw:py-2 tw:text-sm tw:text-gray-500 tw:dark:text-gray-400") }
          dropdown.with_entry_divider
          dropdown.with_entry_item { icon_link("⚙", "Settings") }
          dropdown.with_entry_item { icon_link("↻", "Sync (active)", active: true) }
        end
      end

      def placements
        {template: "ui/dropdown/component_preview/placements"}
      end

      # @!endgroup

      private

      def avatar_button
        avatar = content_tag(:img, nil, src: ActionController::Base.helpers.asset_path("kelsey/illustrations/comic-assets_bike-love-1.png"), class: "tw:rounded-full tw:w-8 tw:h-8 tw:object-cover", alt: "Avatar")
        content_tag(:span, class: "tw:flex tw:items-center tw:gap-2") do
          safe_join([avatar, content_tag(:span, "seth herr")])
        end
      end

      def avatar_button_class
        "tw:flex tw:items-center tw:gap-1 tw:rounded-full tw:bg-gray-100 tw:pr-3 tw:pl-1 tw:py-1 tw:text-sm tw:font-medium tw:text-gray-700 tw:hover:bg-gray-200 tw:dark:bg-gray-700 tw:dark:text-gray-200 tw:dark:hover:bg-gray-600"
      end

      def icon_link(icon, label, active: false)
        content_tag(:a, href: "#", class: "tw:flex tw:items-center tw:gap-2 #{"active" if active}".strip) do
          safe_join([content_tag(:span, icon, class: "tw:text-base"), label])
        end
      end
    end
  end
end
