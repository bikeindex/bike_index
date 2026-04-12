# frozen_string_literal: true

module UI
  module Dropdown
    class Component < ApplicationComponent
      renders_many :items

      def initialize(name:, button_content: nil, drop_direction: :bottom_end, button_class: nil, header: nil, id: nil, placement: nil)
        @name = name
        @button_content = button_content || "#{name} ▼"
        @button_class = button_class || UI::Button::Component.new(color: :secondary).button_classes
        @header = header
        @button_id = id || @name.parameterize(separator: "-")
        @placement = placement || placement_for(drop_direction)
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
