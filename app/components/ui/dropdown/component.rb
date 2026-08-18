# frozen_string_literal: true

module UI
  module Dropdown
    class Component < ApplicationComponent
      # Applied to the <li>; the `[&>a]` variant colors the item's link (the surface).
      # The item flags itself aria-current rather than aria-pressed, which is invalid on
      # role="menuitem" — the is-active variant (application.css) covers both.
      # The fill is UI::Button's secondary active, minus the border and ring a menu item has no room for.
      ACTIVE_COLORS = "tw:is-active:[&>a]:bg-purple-500 tw:is-active:[&>a]:text-white"

      renders_one :button
      renders_many :entries, types: {
        item: lambda { |active: false, &block|
          content_tag(:li, capture(&block), role: "menuitem", class: ACTIVE_COLORS, aria: {current: active || nil})
        },
        divider: lambda {
          content_tag(:li, "", role: "separator")
        }
      }

      def initialize(name:, button_class: nil, button_color: :secondary, button_size: :md, active: false)
        @name = name
        @button_class = button_class
        @button_color = button_color
        @button_size = button_size
        @active = active
      end

      private

      def button_attributes
        {
          type: "button",
          class: button_classes,
          id: button_id,
          aria: {expanded: false},
          data: {action: "click->ui--dropdown#toggle", "ui--dropdown-target": "button", active: @active || nil}
        }
      end

      def button_content
        raw = button? ? button : @name
        (@button_color == :link) ? content_tag(:span, raw, class: "tw:underline") : raw
      end

      def button_classes
        return @button_class if @button_class

        classes = UI::Button::Component.new(color: @button_color, size: @button_size).button_classes
        return classes unless @button_color == :link

        # button_content underlines the label span, so the trigger itself never does — and
        # .twlink's underline is in the components layer, which only a utility outranks
        "#{classes} tw:is-active:no-underline tw:px-1"
      end

      def button_id
        @button_id ||= @name.parameterize(separator: "-")
      end
    end
  end
end
