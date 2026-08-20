# frozen_string_literal: true

module UI
  module Dropdown
    class ComponentPreview < ApplicationComponentPreview
      PREVIEW_PATH = "/rails/view_components/ui/dropdown/component"

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

      # A template, so the entries can render UI::ActiveLink -- the marked one points at the
      # page it's shown on, so the browser fills it
      def custom_button
        {template: "ui/dropdown/component_preview/custom_button"}
      end

      # An entry wider than the button, which the menu sizes to rather than wrapping
      def long_entry
        render(UI::Dropdown::Component.new(name: "Mail")) do |dropdown|
          dropdown.with_entry_item { content_tag(:a, "Inbox", href: "#") }
          dropdown.with_entry_item { content_tag(:a, "Letter opener (view sent mail)", href: "#") }
        end
      end

      # @!endgroup
    end
  end
end
