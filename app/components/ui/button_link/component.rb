# frozen_string_literal: true

module UI
  module ButtonLink
    class Component < ApplicationComponent
      def initialize(href:, text: nil, color: :secondary, size: :md, active: false, html_class: nil, **html_options)
        @text = text
        @href = href
        @color = UI::Button::Component::COLORS.key?(color) ? color : :secondary
        @size = UI::Button::Component::SIZES.key?(size) ? size : :md
        @active = active
        @html_class = html_class
        @html_options = html_options
      end

      def call
        helpers.link_to(@text || content, @href, **@html_options.merge(class: link_classes))
      end

      private

      def link_classes
        UI::Button::Component.build_classes(color: @color, size: @size, active: @active, html_class: @html_class)
      end
    end
  end
end
