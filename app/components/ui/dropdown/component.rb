# frozen_string_literal: true

module UI
  module Dropdown
    class Component < ApplicationComponent
      renders_many :entries, types: {
        item: lambda { |&block|
          content_tag(:li, role: "menuitem", class: "tw:[&>a]:block tw:[&>a]:px-4 tw:[&>a]:py-1 tw:[&>a]:text-gray-700 tw:[&>a]:no-underline tw:[&>a]:hover:bg-gray-100 tw:[&>a]:hover:text-gray-900 tw:dark:[&>a]:text-gray-200 tw:dark:[&>a]:hover:bg-gray-700 tw:dark:[&>a]:hover:text-gray-100", &block)
        },
        divider: lambda {
          content_tag(:li, "", role: "separator", class: "tw:my-1 tw:border-t tw:border-gray-200 tw:dark:border-gray-700")
        }
      }

      alias_method :with_item, :with_entry_item
      alias_method :with_divider, :with_entry_divider

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
