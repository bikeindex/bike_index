# frozen_string_literal: true

module UI
  module Collapse
    # The trigger for a ui--collapse controller on an ancestor, which keeps
    # aria-expanded and the chevron's rotation in sync with its content.
    # chevron: true leads the label with it, :trailing follows. A block renders in place of text.
    class Component < ApplicationComponent
      def initialize(text: nil, chevron: false, aria: {}, data: {}, **button_options)
        @text = text
        @chevron = chevron
        @aria = aria.merge(expanded: "false")
        @data = data.merge(action: "ui--collapse#toggle", "ui--collapse-target": "trigger")
        @button_options = button_options
      end

      def call
        label = content || @text
        render(UI::Button::Component.new(**@button_options, aria: @aria, data: @data)) do
          safe_join(((@chevron == :trailing) ? [label, chevron_span] : [chevron_span, label]).compact)
        end
      end

      private

      def chevron_span
        return unless @chevron

        tag.span(tag.span(render(UI::IconChevron::Component.new), class: "tw:flex"),
          class: "tw:inline-block tw:transition-transform tw:duration-200",
          data: {"ui--collapse-target": "chevron"})
      end
    end
  end
end
