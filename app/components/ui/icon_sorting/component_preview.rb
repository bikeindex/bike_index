# frozen_string_literal: true

module UI
  module IconSorting
    class ComponentPreview < ApplicationComponentPreview
      # @!group Sort direction
      def descending
        render(UI::IconSorting::Component.new(direction: "desc"))
      end

      def ascending
        render(UI::IconSorting::Component.new(direction: "asc"))
      end
      # @!endgroup
    end
  end
end
