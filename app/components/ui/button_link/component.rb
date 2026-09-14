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

      # A button_to's <form> can't nest inside the forms these sit in, so a confirm puts the
      # method on a Turbo link instead
      def call
        return button_to_form if @method && @confirm.nil?
        return disabled_link if @disabled

        helpers.link_to(@text || content, @href, link_attributes)
      end

      private

      # onclick, not data-turbo-confirm (Turbo Drive is off unless a call site opts in) or
      # data-confirm (rails-ujs, which we're retiring); returning false stops Turbo's handler
      def confirmable_attributes
        attributes = html_attributes
        return attributes if @confirm.nil?

        turbo = @method ? {turbo: true, turbo_method: @method} : {}
        attributes.merge(onclick: "return confirm('#{j @confirm}')", data: attributes[:data].merge(turbo))
      end

      # The spacebar activates a button but scrolls the page on a link, and this renders as
      # a button -- ui--button-link clicks it instead
      def link_attributes
        attributes = confirmable_attributes
        data = attributes[:data]

        attributes.merge(data: data.merge(
          controller: [data[:controller], "ui--button-link"].compact.join(" "),
          action: [data[:action], "keydown->ui--button-link#activate"].compact.join(" ")
        ))
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
