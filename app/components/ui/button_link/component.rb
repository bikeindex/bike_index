# frozen_string_literal: true

module UI
  module ButtonLink
    class Component < ApplicationComponent
      def initialize(href:, text: nil, color: :secondary, size: :md, active: false, method: nil, html_class: nil, **html_options)
        @text = text
        @href = href
        @color = color
        @size = UI::Button::Component::SIZES.key?(size) ? size : :md
        @active = active
        @method = method
        @html_class = html_class
        @data = html_options.delete(:data) || {}
        @disabled = html_options.delete(:disabled)
        @html_options = html_options

        UI::Button::Component.validate_options!(color: @color, size: @size, html_options:)
      end

      # Passing method: renders a button_to form (a styled button that submits a
      # request to href) instead of a plain link. html_options flow through, so a
      # form: {onsubmit:} confirm reaches the wrapping form.
      def call
        return button_to_form if @method
        return disabled_link if @disabled

        helpers.link_to(@text || content, @href, html_attributes)
      end

      private

      # An <a> takes no disabled attribute, so dropping the href is what makes it
      # unfollowable; aria says so, and tabindex -1 takes it out of the tab order.
      def disabled_link
        content_tag(:a, @text || content, **html_attributes, role: "link", tabindex: -1,
          aria: (@html_options[:aria] || {}).merge(disabled: true))
      end

      def button_to_form
        helpers.button_to(@href, html_attributes.merge(method: @method, disabled: @disabled)) do
          @text || content
        end
      end

      def html_attributes
        @html_options.merge(class: link_classes, data: @data.merge(active: @active || nil))
      end

      def link_classes
        UI::Button::Component.build_classes(color: @color, size: @size, html_class: @html_class)
      end
    end
  end
end
