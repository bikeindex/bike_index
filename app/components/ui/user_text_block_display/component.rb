# frozen_string_literal: true

module UI
  module UserTextBlockDisplay
    class Component < ApplicationComponent
      def initialize(text: nil, additional_classes: nil, max_height_class: "tw:max-h-80")
        @text = text&.strip
        overflow_class = "tw:overflow-y-auto" if max_height_class.present?
        @classes = ["tw:whitespace-pre-wrap", overflow_class, additional_classes, max_height_class]
      end

      def render?
        @text.present?
      end

      # NOTE: rendered inline rather than via a template so the text block has no
      # leading whitespace (see spec)
      def call
        tag.div(@text, class: @classes)
      end
    end
  end
end
