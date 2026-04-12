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
          button_content: avatar_button,
          button_class: avatar_button_class,
          header: content_tag(:div, "Last synced: 2 minutes ago", class: "tw:px-4 tw:py-2 tw:text-sm tw:text-gray-500 tw:dark:text-gray-400")
        )) do |dropdown|
          dropdown.with_entry_item { icon_link("⚙", "Settings") }
          dropdown.with_entry_item { icon_link("↻", "Sync") }
        end
      end

      # @label bottom_start (button_size: :sm)
      def bottom_start
        render_placement(:bottom_start, button_size: :sm)
      end

      # @label top_end (button_size: :lg)
      def top_end
        render_placement(:top_end, button_size: :lg)
      end

      # @label top_start (button_color: :primary)
      def top_start
        render_placement(:top_start, button_color: :primary)
      end

      # @label right (button_color: :error)
      def right
        render_placement(:right, button_color: :error)
      end

      def left
        render_placement(:left)
      end

      # @!endgroup

      private

      def render_placement(direction, button_size: :md, button_color: :secondary)
        render(UI::Dropdown::Component.new(name: direction.to_s.tr("_", " "), drop_direction: direction, button_size:, button_color:, wrapper_class: "tw:block! tw:w-fit tw:mx-auto")) do |d|
          d.with_entry_item { content_tag(:a, "Option 1", href: "#") }
          d.with_entry_item { content_tag(:a, "Option 2", href: "#") }
        end
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
