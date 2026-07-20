# frozen_string_literal: true

module UI
  module IconChevron
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(UI::IconChevron::Component.new(html_class: "tw:size-8"))
      end

      # @label rotated (open/expanded state)
      def rotated
        render(UI::IconChevron::Component.new(html_class: "tw:size-8 tw:rotate-180"))
      end
    end
  end
end
