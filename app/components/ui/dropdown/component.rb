# frozen_string_literal: true

module UI
  module Dropdown
    class Component < ApplicationComponent
      # Applied to the <li>; the `[&>a]` variant colors the item's link (the surface).
      # The item flags itself aria-current rather than aria-pressed, which is invalid on
      # role="menuitem" — the is-active variant (application.css) covers both.
      ACTIVE_COLORS = "tw:is-active:[&>a]:bg-gray-200 tw:is-active:[&>a]:text-gray-900 tw:is-active:dark:[&>a]:bg-gray-600 tw:is-active:dark:[&>a]:text-gray-100"

      renders_one :button
      renders_many :entries, types: {
        item: lambda { |active: false, &block|
          content_tag(:li, capture(&block), role: "menuitem", class: ACTIVE_COLORS, aria: {current: active || nil})
        },
        divider: lambda {
          content_tag(:li, "", role: "separator")
        }
      }

      # The menu shrink-to-fits against the wrapper, which is only as wide as the
      # button, so long entries wrap -- menu_class: "tw:w-max" sizes it to them instead
      MENU_CLASSES = "tw:absolute tw:top-0 tw:left-0 tw:hidden tw:min-w-44 tw:rounded-lg " \
        "tw:border tw:border-gray-200 tw:bg-white tw:shadow-lg " \
        "tw:dark:border-gray-700 tw:dark:bg-gray-800"

      def initialize(name:, button_class: nil, button_color: :secondary, button_size: :md, active: false,
        menu_class: nil)
        @name = name
        @button_class = button_class
        @button_color = button_color
        @button_size = button_size
        @active = active
        @menu_class = menu_class
      end

      private

      def menu_classes
        [MENU_CLASSES, @menu_class].compact.join(" ")
      end

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
        if @button_color == :link
          # button_content underlines the label span, so the trigger itself never does.
          classes = classes.sub("tw:is-active:underline", "").squeeze(" ").strip + " tw:px-1"
        end
        classes
      end

      def button_id
        @button_id ||= @name.parameterize(separator: "-")
      end
    end
  end
end
