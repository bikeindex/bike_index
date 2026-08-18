# frozen_string_literal: true

module UI
  module Tooltip
    class Component < ApplicationComponent
      TRIGGER_ACTIONS = "mouseenter->ui--tooltip#showOnHover mouseleave->ui--tooltip#hideOnHover " \
        "focusin->ui--tooltip#showOnFocus focusout->ui--tooltip#hideOnFocusout"

      TRIGGER_CLASS = "tw:inline-block tw:rounded tw:cursor-help " \
        "tw:focus:outline-none tw:focus:ring-3 tw:focus:ring-blue-500/40"

      BUTTON_CLASS = "tw:inline-flex tw:items-center tw:justify-center tw:h-4 tw:w-4 tw:rounded-full " \
        "tw:bg-gray-200 tw:text-gray-700 tw:hover:bg-gray-300 " \
        "tw:dark:bg-gray-700 tw:dark:text-gray-200 tw:dark:hover:bg-gray-600 " \
        "tw:text-2xs tw:font-bold tw:cursor-help " \
        "tw:focus:outline-none tw:focus:ring-3 tw:focus:ring-blue-500/40"

      renders_one :body
      renders_one :tooltip_button, ->(**attrs, &block) {
        tag.button(**trigger_attrs(class: BUTTON_CLASS, **attrs)) { block ? capture(&block) : "?" }
      }

      def initialize(text: nil)
        @text = text
      end

      # The controller and its hover/focus actions live on the wrapping span so
      # the trigger and the tooltip are siblings — a link in the tooltip body
      # can't be nested inside the trigger button.
      def call
        tag.span(class: "tw:inline-block", data: {controller: "ui--tooltip", action: TRIGGER_ACTIONS}) do
          safe_join([trigger, tooltip_span], " ")
        end
      end

      private

      # With no trigger content, fall back to the "?" button — the default way
      # tooltips are rendered.
      def trigger
        return tooltip_button if tooltip_button?
        return tag.button(**trigger_attrs(class: BUTTON_CLASS)) { "?" } if content.blank?

        tag.button(**trigger_attrs(class: TRIGGER_CLASS)) { content }
      end

      def trigger_attrs(data: {}, **extra_attrs)
        {
          type: "button",
          "aria-label": @text.presence,
          "aria-describedby": tooltip_id,
          data: {"ui--tooltip-target": "trigger", **data},
          **extra_attrs
        }
      end

      def tooltip_id
        @tooltip_id ||= "tooltip-#{SecureRandom.hex(4)}"
      end

      def tooltip_body
        body? ? body : @text
      end

      # A link or button in the body means the tooltip is meant to be clicked
      # into (it stays open on click), so the popup needs pointer events.
      def interactive_body?
        tooltip_body.to_s.match?(/<(a|button)[\s>]/)
      end

      def tooltip_span
        pointer = interactive_body? ? "tw:pointer-events-auto" : "tw:pointer-events-none"
        tag.span(
          tooltip_body,
          role: "tooltip",
          id: tooltip_id,
          data: {"ui--tooltip-target": "tooltip"},
          class: "tw:twtext-color tw:hidden #{pointer} tw:whitespace-nowrap tw:rounded " \
            "tw:bg-white tw:px-2 tw:py-1 tw:text-xs tw:font-normal tw:border tw:border-gray-200 tw:shadow-lg tw:z-50 " \
            "tw:dark:bg-gray-800 tw:dark:border-gray-700"
        )
      end
    end
  end
end
