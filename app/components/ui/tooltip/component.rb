# frozen_string_literal: true

module UI
  module Tooltip
    class Component < ApplicationComponent
      TRIGGER_ACTIONS = "mouseenter->ui--tooltip#showOnHover mouseleave->ui--tooltip#hideOnHover " \
        "focusin->ui--tooltip#showOnFocus focusout->ui--tooltip#hideOnFocusout"

      TRIGGER_CLASS = "tw:inline-block tw:rounded tw:cursor-help " \
        "tw:focus:outline-none tw:focus:ring-3 tw:focus:ring-blue-500/40"

      renders_one :body
      renders_one :tooltip_button, ->(**attrs, &block) {
        inner = block ? safe_join([capture(&block), tooltip_span], " ") : tooltip_span
        tag.button(**trigger_attrs(**attrs)) { inner }
      }

      def initialize(text: nil)
        @text = text
      end

      def call
        return tooltip_button if tooltip_button?

        tag.button(**trigger_attrs(class: TRIGGER_CLASS)) { safe_join([content, tooltip_span], " ") }
      end

      private

      def trigger_attrs(data: {}, **extra_attrs)
        action = [data[:action], TRIGGER_ACTIONS].compact.join(" ")
        {
          type: "button",
          "aria-label": @text.presence,
          "aria-describedby": tooltip_id,
          data: {controller: "ui--tooltip", "ui--tooltip-target": "trigger", **data, action:},
          **extra_attrs
        }
      end

      def tooltip_id
        @tooltip_id ||= "tooltip-#{SecureRandom.hex(4)}"
      end

      def tooltip_body
        body? ? body : @text
      end

      def tooltip_span
        tag.span(
          tooltip_body,
          role: "tooltip",
          id: tooltip_id,
          data: {"ui--tooltip-target": "tooltip"},
          class: "twtext-color tw:hidden tw:pointer-events-none tw:whitespace-nowrap tw:rounded " \
            "tw:bg-white tw:px-2 tw:py-1 tw:text-xs tw:font-normal tw:border tw:border-gray-200 tw:shadow-lg tw:z-50 " \
            "tw:dark:bg-gray-800 tw:dark:border-gray-700"
        )
      end
    end
  end
end
