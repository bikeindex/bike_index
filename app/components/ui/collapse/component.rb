# frozen_string_literal: true

module UI
  module Collapse
    # The trigger for a ui--collapse controller on an ancestor, which keeps
    # aria-expanded and the chevron's rotation in sync with its content.
    # chevron: true leads the label with it, :trailing follows. A block renders in place of text.
    # selectable: true renders a role=button span styled as the button would have been, since
    # Safari won't select a button's text.
    class Component < ApplicationComponent
      ACTIONS = "mousedown->ui--collapse#press click->ui--collapse#toggle"
      KEY_ACTIONS = "keydown.enter->ui--collapse#toggle:prevent keydown.space->ui--collapse#toggle:prevent"

      def initialize(text: nil, chevron: false, selectable: false, aria: {}, data: {}, **button_options)
        raise ArgumentError, "a selectable trigger can't be disabled" if selectable && button_options[:disabled]

        @text = text
        @chevron = chevron
        @selectable = selectable
        @aria = aria.merge(expanded: "false")
        @data = data.merge("ui--collapse-target": "trigger")
        @button_options = button_options
      end

      def call
        label = content || @text
        inner = safe_join(((@chevron == :trailing) ? [label, chevron_span] : [chevron_span, label]).compact)
        unless @selectable
          return render(UI::Button::Component.new(**@button_options, aria: @aria, data: @data.merge(action: ACTIONS))) { inner }
        end

        tag.span(inner, **@button_options.except(:color, :size, :html_class, :active), role: "button", tabindex: 0,
          class: selectable_classes, aria: @aria, data: @data.merge(action: "#{ACTIONS} #{KEY_ACTIONS}"))
      end

      private

      # .twlink bolds when active, which :active makes it for the length of a drag-select,
      # reflowing the label under the pointer. A caller's own weight already outranks it
      def selectable_classes
        pin_weight = @button_options[:color] == :link && !@button_options[:html_class].to_s.include?("tw:font-")
        [UI::Button::Component.new(**@button_options).button_classes, ("tw:[font-weight:inherit]" if pin_weight)].compact.join(" ")
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
