# frozen_string_literal: true

module UI
  module Dropdown
    class Component < ApplicationComponent
      # Literal strings so Tailwind's scanner generates these aria-current:/active: variants.
      # Applied to the <li>; the `[&>a]` variant colors the item's link (the surface).
      # aria-current (not aria-pressed) because aria-pressed is invalid on role="menuitem".
      ACTIVE_PREFIXED = "tw:aria-[current]:[&>a]:bg-gray-200 tw:active:[&>a]:bg-gray-200 tw:aria-[current]:[&>a]:text-gray-900 tw:active:[&>a]:text-gray-900 tw:aria-[current]:dark:[&>a]:bg-gray-600 tw:active:dark:[&>a]:bg-gray-600 tw:aria-[current]:dark:[&>a]:text-gray-100 tw:active:dark:[&>a]:text-gray-100"

      renders_one :button
      renders_many :entries, types: {
        item: lambda { |active: false, &block|
          content_tag(:li, capture(&block), role: "menuitem", class: ACTIVE_PREFIXED, aria: {current: active || nil})
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

      def button_content
        raw = button? ? button : @name
        (@button_color == :link) ? content_tag(:span, raw, class: "tw:underline") : raw
      end

      def button_classes
        return @button_class if @button_class

        classes = UI::Button::Component.new(color: @button_color, size: @button_size, active: @active).button_classes
        if @button_color == :link
          classes = classes.gsub("tw:underline", "").squeeze(" ").strip + " tw:px-1"
        end
        classes
      end

      def button_id
        @button_id ||= @name.parameterize(separator: "-")
      end
    end
  end
end
