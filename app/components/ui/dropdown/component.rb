# frozen_string_literal: true

module UI
  module Dropdown
    class Component < ApplicationComponent
      renders_many :entries, types: {
        item: lambda { |&block|
          content_tag(:li, role: "menuitem", &block)
        },
        divider: lambda {
          content_tag(:li, "", role: "separator")
        }
      }

      PLACEMENTS = {
        bottom_end: "bottom-end",
        bottom_start: "bottom-start",
        bottom: "bottom",
        top_end: "top-end",
        top_start: "top-start",
        top: "top",
        right: "right",
        left: "left"
      }.freeze

      def initialize(name:, button_content: nil, drop_direction: :bottom_end, button_class: nil, button_color: :secondary, button_size: :md, header: nil, id: nil)
        @name = name
        @button_content = button_content || name
        @button_class = button_class
        @button_color = button_color
        @button_size = button_size
        @header = header
        @button_id = id || @name.parameterize(separator: "-")
        @placement = PLACEMENTS.fetch(drop_direction, PLACEMENTS[:bottom_end])
      end

      def button_component
        UI::Button::Component.new(
          color: @button_color,
          size: @button_size,
          html_class: @button_class,
          id: @button_id,
          aria: {expanded: false},
          data: {action: "click->dropdown#toggle", dropdown_target: "button"}
        )
      end

      def floating_ui_placement
        @placement
      end

      private
    end
  end
end
