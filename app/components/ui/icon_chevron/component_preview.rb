# frozen_string_literal: true

module UI
  module IconChevron
    class ComponentPreview < ApplicationComponentPreview
      # @!group Chevron
      def right
        render(UI::IconChevron::Component.new(direction: :right))
      end

      def down
        render(UI::IconChevron::Component.new(direction: :down))
      end

      def left
        render(UI::IconChevron::Component.new(direction: :left))
      end

      def up
        render(UI::IconChevron::Component.new(direction: :up))
      end

      def sm
        render(UI::IconChevron::Component.new(size: :sm))
      end

      def md
        render(UI::IconChevron::Component.new(size: :md))
      end

      # @label with extra classes appended
      def with_html_class
        render(UI::IconChevron::Component.new(direction: :down, html_class: "tw:ml-1 tw:text-gray-400"))
      end
      # @!endgroup
    end
  end
end
