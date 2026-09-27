# frozen_string_literal: true

module UI
  module Collapse
    # The trigger for a ui--collapse controller on an ancestor, which keeps
    # aria-expanded and the chevron's rotation in sync with its content.
    # chevron: true leads the label with it, :trailing follows. A block renders in place of text.
    # selectable: true puts the label beside a chevron-only button rather than inside it, since
    # Safari won't select a button's text. The row around both takes the clicks, styled as the
    # button would have been.
    class Component < ApplicationComponent
      ACTIONS = "mousedown->ui--collapse#press click->ui--collapse#toggle"

      def initialize(text: nil, chevron: false, selectable: false, aria: {}, data: {}, **button_options)
        @text = text
        @chevron = chevron
        @selectable = selectable
        @aria = aria.merge(expanded: "false")
        @data = data.merge("ui--collapse-target": "trigger")
        @button_options = button_options
      end

      def call
        label = content || @text
        return button(label, @button_options, @aria, @data.merge(action: ACTIONS)) unless @selectable

        label_id = "ui-collapse-label-#{object_id}"
        parts = [button(nil, {color: :link, html_class: "tw:text-inherit"}, @aria.merge(labelledby: label_id), @data),
          tag.span(label, id: label_id, class: "tw:contents")]
        tag.div(safe_join((@chevron == :trailing) ? parts.reverse : parts),
          class: UI::Button::Component.new(**@button_options).button_classes, data: {action: ACTIONS})
      end

      private

      def button(label, button_options, aria, data)
        render(UI::Button::Component.new(**button_options, aria:, data:)) do
          safe_join(((@chevron == :trailing) ? [label, chevron_span] : [chevron_span, label]).compact)
        end
      end

      def chevron_span
        return unless @chevron

        tag.span(tag.span(render(UI::IconChevron::Component.new), class: "tw:flex"),
          class: "tw:inline-block tw:transition-transform tw:duration-200",
          data: {"ui--collapse-target": "chevron"})
      end
    end
  end
end
