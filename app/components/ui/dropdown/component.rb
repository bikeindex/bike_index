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

      def initialize(name:, button_content: nil, drop_direction: :bottom_end, button_class: nil, button_color: :secondary, button_size: :md, header: nil, id: nil, placement: nil)
        @name = name
        @button_content = button_content || name
        @button_class = button_class
        @button_color = button_color
        @button_size = button_size
        @header = header
        @button_id = id || @name.parameterize(separator: "-")
        @placement = placement || placement_for(drop_direction)
      end

      def button_classes
        @button_class || UI::Button::Component.new(color: @button_color, size: @button_size).button_classes
      end

      def floating_ui_placement
        @placement
      end

      private

      def placement_for(direction)
        case direction
        when :bottom_start then "bottom-start"
        else "bottom-end"
        end
      end
    end
  end
end
