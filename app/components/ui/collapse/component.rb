# frozen_string_literal: true

module UI
  module Collapse
    # The trigger for a ui--collapse controller on an ancestor, which keeps
    # aria-expanded and the chevron's rotation in sync with its content.
    # chevron: true leads the label with it, :trailing follows. A block renders in place of text.
    # A role=button span styled as UI::Button, since Safari won't select a button's text.
    class Component < ApplicationComponent
      ACTIONS = "mousedown->ui--collapse#press click->ui--collapse#toggle " \
        "keydown.enter->ui--collapse#toggle:prevent keydown.space->ui--collapse#toggle:prevent"

      def initialize(text: nil, chevron: false, aria: {}, data: {}, **button_options)
        raise ArgumentError, "a collapse trigger can't be disabled" if button_options[:disabled]

        @text = text
        @chevron = chevron
        @aria = aria.merge(expanded: "false")
        @data = data.merge("ui--collapse-target": "trigger", action: ACTIONS)
        @button_options = button_options
      end

      def call
        label = content || @text
        tag.span(safe_join(((@chevron == :trailing) ? [label, chevron_span] : [chevron_span, label]).compact),
          **@button_options.except(:color, :size, :html_class, :active), role: "button", tabindex: 0,
          class: trigger_classes, aria: @aria, data: @data)
      end

      private

      # .twlink bolds when active, which :active makes a closed trigger for the length of a drag-select,
      # reflowing the label under the pointer. A caller's own weight already outranks it
      def trigger_classes
        pin_weight = @button_options[:color] == :link && !@button_options[:html_class].to_s.include?("tw:font-")
        [UI::Button::Component.new(**@button_options).button_classes,
          ("tw:not-data-[active=true]:[font-weight:inherit]" if pin_weight)].compact.join(" ")
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
