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

      # Link color, where only the label is underlined — hover and press it to see the
      # chevron stay clear of the underline .twlink would otherwise put across both
      def link_button
        render(UI::Dropdown::Component.new(name: "Mailers", button_color: :link, active: true)) do |dropdown|
          dropdown.with_entry_item { content_tag(:a, "Organized", href: "#") }
          dropdown.with_entry_item { content_tag(:a, "Customer", href: "#") }
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
          dropdown.with_entry_item(active: true) { icon_link("↻", "Sync (active)") }
        end
      end

      # An entry wider than the button, which the menu sizes to rather than wrapping
      def long_entry
        render(UI::Dropdown::Component.new(name: "Mail")) do |dropdown|
          dropdown.with_entry_item { content_tag(:a, "Inbox", href: "#") }
          dropdown.with_entry_item { content_tag(:a, "Letter opener (view sent mail)", href: "#") }
        end
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

      def icon_link(icon, label)
        content_tag(:a, href: "#", class: "tw:flex tw:items-center tw:gap-2") do
          safe_join([content_tag(:span, icon, class: "tw:text-base"), label])
        end
      end
    end
  end
end
