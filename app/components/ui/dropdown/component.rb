# frozen_string_literal: true

module UI
  module Dropdown
    class Component < ApplicationComponent
      renders_one :button
      renders_many :entries, types: {
        item: lambda { |&block|
          content_tag(:li, nil, role: "menuitem", &block)
        },
        divider: lambda {
          content_tag(:li, "", role: "separator")
        }
      }

      PLACEMENTS = {
        bottom_end: "bottom-end",
        bottom_start: "bottom-start",
        top_end: "top-end",
        top_start: "top-start",
        right: "right",
        left: "left"
      }.freeze

      def initialize(name:, drop_direction: :bottom_end, button_class: nil, button_color: :secondary, button_size: :md, active: false)
        @name = name
        @button_class = button_class
        @button_color = button_color
        @button_size = button_size
        @active = active
        @placement = PLACEMENTS.fetch(drop_direction, PLACEMENTS[:bottom_end])
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

      def floating_ui_placement
        @placement
      end
    end
  end
end
