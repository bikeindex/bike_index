# frozen_string_literal: true

module UI
  module ButtonLink
    class Component < ApplicationComponent
      def initialize(href:, text: nil, color: :secondary, size: :md, active: false, method: nil, confirm: nil, html_class: nil, **html_options)
        @text = text
        @href = href
        @color = color
        @size = UI::Button::Component::SIZES.key?(size) ? size : :md
        @active = active
        @method = method
        @confirm = confirm
        @html_class = html_class
        @data = html_options.delete(:data) || {}
        @disabled = html_options.delete(:disabled)
        @form = html_options.delete(:form) || {}
        @html_options = html_options

        UI::Button::Component.validate_options!(color: @color, size: @size, html_options:)
      end

      # Passing method: renders a button_to form (a styled button that submits a
      # request to href) instead of a plain link — unless it also has to prompt, since a
      # button_to's form can't nest inside the forms these sit in. Then Turbo carries the
      # method on a link instead.
      def call
        return button_to_form if @method && @confirm.nil?
        return disabled_link if @disabled

        helpers.link_to(@text || content, @href, confirmable_attributes)
      end

      private

      # onclick, not data-turbo-confirm (Turbo Drive is off unless a call site opts in) and
      # not data-confirm (rails-ujs, which we're retiring). Turbo's click handler checks
      # defaultPrevented, so returning false here stops the request it would have issued.
      def confirmable_attributes
        return html_attributes if @confirm.nil?

        attributes = html_attributes.merge(onclick: "return confirm('#{j @confirm}')")
        return attributes if @method.nil?

        attributes.merge(data: attributes[:data].merge(turbo: true, turbo_method: @method))
      end

      # An <a> takes no disabled attribute, so dropping the href is what makes it
      # unfollowable; aria says so, and tabindex -1 takes it out of the tab order.
      def disabled_link
        content_tag(:a, @text || content, **html_attributes, role: "link", tabindex: -1,
          aria: (@html_options[:aria] || {}).merge(disabled: true))
      end

      def button_to_form
        helpers.button_to(@href, html_attributes.merge(method: @method, disabled: @disabled, form: @form)) do
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
