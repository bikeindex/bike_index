# frozen_string_literal: true

module UI
  module ButtonLink
    class Component < ApplicationComponent
      def initialize(href:, text: nil, color: :secondary, size: :md, active: false, **html_options)
        @text = text
        @href = href
        @color = UI::Button::Component::COLORS.key?(color) ? color : :secondary
        @size = UI::Button::Component::SIZES.key?(size) ? size : :md
        @active = active
        @html_options = html_options
      end

      def call
        helpers.link_to(@text || content, @href, **@html_options.merge(class: link_classes))
      end

      private

      def link_classes
        classes = [
          UI::Button::Component::BASE_CLASSES,
          UI::Button::Component::COLORS[@color],
          UI::Button::Component::SIZES[@size],
          @html_options[:class]
        ]
        classes << UI::Button::Component::ACTIVE_COLORS[@color] if @active
        classes.compact.join(" ")
      end
    end
  end
end
