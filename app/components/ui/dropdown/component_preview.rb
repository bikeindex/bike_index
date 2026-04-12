# frozen_string_literal: true

module UI
  module Dropdown
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants

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
          button_content: avatar_button,
          button_class: avatar_button_class,
          header: content_tag(:div, "Last synced: 2 minutes ago", class: "tw:px-4 tw:py-2 tw:text-sm tw:text-gray-500 tw:dark:text-gray-400")
        )) do |dropdown|
          dropdown.with_entry_item { icon_link("⚙", "Settings") }
          dropdown.with_entry_item { icon_link("↻", "Sync") }
        end
      end

      def bottom_end
        render_placement(:bottom_end)
      end

      def bottom_start
        render_placement(:bottom_start, wrapper_class: "tw:ml-48")
      end

      def top_end
        render_placement(:top_end)
      end

      def top_start
        render_placement(:top_start, wrapper_class: "tw:ml-48")
      end

      def right
        render_placement(:right)
      end

      def left
        render_placement(:left, wrapper_class: "tw:ml-48")
      end

      # @!endgroup

      private

      def render_placement(direction, wrapper_class: nil)
        dropdown = render(UI::Dropdown::Component.new(name: direction.to_s.tr("_", " "), drop_direction: direction)) do |d|
          d.with_entry_item { content_tag(:a, "Option 1", href: "#") }
          d.with_entry_item { content_tag(:a, "Option 2", href: "#") }
        end
        wrapper_class ? content_tag(:div, dropdown, class: wrapper_class) : dropdown
      end

      def avatar_button
        avatar = content_tag(:img, nil, src: ActionController::Base.helpers.asset_path("kelsey/illustrations/comic-assets_bike-love-1.png"), class: "tw:rounded-full tw:w-8 tw:h-8 tw:object-cover", alt: "Avatar")
        content_tag(:span, class: "tw:flex tw:items-center tw:gap-2") do
          safe_join([avatar, content_tag(:span, "seth herr")])
        end
      end

      def avatar_button_class
        "tw:flex tw:items-center tw:gap-1 tw:rounded-full tw:bg-gray-100 tw:pr-3 tw:pl-1 tw:py-1 tw:text-sm tw:font-medium tw:text-gray-700 tw:hover:bg-gray-200 tw:dark:bg-gray-700 tw:dark:text-gray-200 tw:dark:hover:bg-gray-600"
      end

      def icon_link(icon, label)
        content_tag(:a, href: "#", class: "tw:flex tw:items-center tw:gap-2") do
          safe_join([content_tag(:span, icon, class: "tw:text-base"), label])
        end
      end
    end
  end
end
