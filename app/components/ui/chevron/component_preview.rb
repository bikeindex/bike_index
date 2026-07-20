# frozen_string_literal: true

module UI
  module Chevron
    class ComponentPreview < ApplicationComponentPreview
      # @!group Directions
      def right
        render(UI::Chevron::Component.new(direction: :right))
      end

      def down
        render(UI::Chevron::Component.new(direction: :down))
      end

      def left
        render(UI::Chevron::Component.new(direction: :left))
      end

      def up
        render(UI::Chevron::Component.new(direction: :up))
      end

      # @!endgroup

      # @!group Sizes
      def sm
        render(UI::Chevron::Component.new(size: :sm))
      end

      def md
        render(UI::Chevron::Component.new(size: :md))
      end

      # @!endgroup

      # @label with extra classes appended
      def with_html_class
        render(UI::Chevron::Component.new(direction: :down, html_class: "tw:ml-1 tw:text-gray-400"))
      end
    end
  end
end
