# frozen_string_literal: true

module UI
  module Collapse
    # The trigger for a ui--collapse controller on an ancestor. The controller keeps
    # aria-expanded and the chevron's rotation in sync, so expanded: is only the
    # rendered state. Everything else is passed through to UI::Button.
    class Component < ApplicationComponent
      CHEVRON_CLASSES = "tw:inline-block tw:transition-transform tw:duration-200"

      def initialize(text: nil, chevron: false, expanded: false, aria: {}, data: {}, **button_options)
        @text = text
        @chevron = chevron
        @expanded = expanded
        @aria = aria.merge(expanded: expanded.to_s)
        @data = data.merge(action: "ui--collapse#toggle", "ui--collapse-target": "trigger")
        @button_options = button_options
      end

      def call
        render(UI::Button::Component.new(**@button_options, aria: @aria, data: @data)) do
          safe_join([chevron_span, @text || content].compact)
        end
      end

      private

      def chevron_span
        return unless @chevron

        tag.span(tag.span(render(UI::IconChevron::Component.new), class: "tw:flex"),
          class: class_names(CHEVRON_CLASSES, "tw:rotate-90": @expanded),
          data: {"ui--collapse-target": "chevron"})
      end
    end
  end
end
