# frozen_string_literal: true

module UI
  module Dropdown
    class Component < ApplicationComponent
      renders_one :button
      # Which entry is current is UI::ActiveLink's, on the entry's own link -- .twdropdown
      # (bike_index_components.css) styles whichever one it marks
      renders_many :entries, types: {
        item: lambda { |&block|
          content_tag(:li, capture(&block), role: "menuitem")
        },
        divider: lambda {
          content_tag(:li, "", role: "separator")
        }
      }

      # open: renders it already showing, for a preview of what's inside it
      def initialize(name:, button_class: nil, button_color: :secondary, button_size: :md, active: false,
        open: false)
        @name = name
        @button_class = button_class
        @button_color = button_color
        @button_size = button_size
        @active = active
        @open = open
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

        # button_content underlines the label span, so the trigger itself never does — the
        # chevron would be underlined with it. .twlink underlines on both hover and active
        # from the components layer, which is why it takes a utility to hold it off.
        # UI::Button gives every other color this same tw:no-underline.
        "#{classes} tw:no-underline tw:px-1"
      end

      def button_id
        @button_id ||= @name.parameterize(separator: "-")
      end
    end
  end
end
