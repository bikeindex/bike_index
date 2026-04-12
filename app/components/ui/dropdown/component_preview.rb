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
        avatar = content_tag(:img, nil, src: "https://placekitten.com/40/40", class: "tw:rounded-full tw:w-8 tw:h-8", alt: "Avatar")
        button = content_tag(:span, class: "tw:flex tw:items-center tw:gap-2") do
          safe_join([avatar, content_tag(:span, "seth herr")])
        end

        render(UI::Dropdown::Component.new(
          name: "User",
          button_content: button,
          button_class: "tw:flex tw:items-center tw:gap-1 tw:rounded-full tw:bg-gray-100 tw:pr-3 tw:pl-1 tw:py-1 tw:text-sm tw:font-medium tw:text-gray-700 tw:hover:bg-gray-200 tw:dark:bg-gray-700 tw:dark:text-gray-200 tw:dark:hover:bg-gray-600",
          header: content_tag(:div, "Last synced: 2 minutes ago", class: "tw:px-4 tw:py-2 tw:text-sm tw:text-gray-500 tw:dark:text-gray-400")
        )) do |dropdown|
          dropdown.with_entry_item do
            content_tag(:a, href: "#", class: "tw:flex tw:items-center tw:gap-2") do
              safe_join([content_tag(:span, "⚙", class: "tw:text-base"), "Settings"])
            end
          end
          dropdown.with_entry_item do
            content_tag(:a, href: "#", class: "tw:flex tw:items-center tw:gap-2") do
              safe_join([content_tag(:span, "↻", class: "tw:text-base"), "Sync"])
            end
          end
        end
      end

      # @!endgroup
    end
  end
end
