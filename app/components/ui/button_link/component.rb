# frozen_string_literal: true

module UI
  module ButtonLink
    class Component < ApplicationComponent
      def initialize(href:, text: nil, color: :secondary, size: :md, active: false, method: nil, **html_options)
        @text = text
        @href = href
        @color = UI::Button::Component::COLORS.key?(color) ? color : :secondary
        @size = UI::Button::Component::SIZES.key?(size) ? size : :md
        @active = active
        @method = method
        @html_options = html_options
      end

      # Passing method: renders a button_to form (a styled button that submits a
      # request to href) instead of a plain link. html_options flow through, so a
      # form: {onsubmit:} confirm reaches the wrapping form.
      def call
        return button_to_form if @method

        helpers.link_to(@text || content, @href, **@html_options.merge(class: link_classes))
      end

      private

      def button_to_form
        helpers.button_to(@href, @html_options.merge(class: link_classes, method: @method)) do
          @text || content
        end
      end

      def link_classes
        UI::Button::Component.build_classes(color: @color, size: @size, active: @active, html_class: @html_options[:class])
      end
    end
  end
end
