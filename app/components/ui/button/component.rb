# frozen_string_literal: true

module UI
  module Button
    # Renders a <button>. For a link styled as a button, or an action button that
    # submits a request to a URL (button_to), use UI::ButtonLink instead — it reuses
    # this component's build_classes, so the two stay visually in lockstep.
    class Component < ApplicationComponent
      BASE_CLASSES = "tw:inline-flex tw:items-center tw:justify-center tw:gap-1.5 tw:rounded-lg tw:cursor-pointer tw:transition-colors"

      SIZES = {
        sm: "tw:px-2.5 tw:py-1 tw:text-xs",
        md: "tw:px-3 tw:py-1.5 tw:text-sm",
        lg: "tw:px-4 tw:py-2 tw:text-base"
      }.freeze

      COLORS = {
        primary: "tw:text-white tw:bg-blue-600 tw:border tw:border-blue-600 tw:hover:bg-blue-700 tw:focus:ring-blue-500/40 tw:dark:bg-blue-500 tw:dark:border-blue-500 tw:dark:hover:bg-blue-600",
        secondary: "tw:text-gray-800 tw:bg-white tw:border tw:border-gray-300 tw:hover:bg-gray-50 tw:hover:border-gray-400 tw:focus:ring-blue-500/40 tw:dark:bg-transparent tw:dark:text-gray-100 tw:dark:border-gray-600 tw:dark:hover:bg-gray-800",
        error: "tw:text-white tw:bg-red-600 tw:border tw:border-red-600 tw:hover:bg-red-700 tw:focus:ring-red-500/40 tw:dark:bg-red-500 tw:dark:border-red-500 tw:dark:hover:bg-red-600",
        purple: "tw:text-white tw:bg-purple-500 tw:border tw:border-purple-500 tw:hover:bg-purple-600 tw:hover:border-purple-600 tw:focus:ring-purple-500/40",
        danger_outline: "tw:text-[#c0392b] tw:bg-white tw:border tw:border-[#f3c9c9] tw:hover:bg-red-50 tw:focus:ring-red-500/40 tw:dark:bg-transparent tw:dark:text-red-400 tw:dark:border-red-900 tw:dark:hover:bg-red-950",
        purple_outline: "tw:text-gray-800 tw:bg-white tw:border tw:border-gray-200 tw:hover:border-purple-500 tw:hover:bg-purple-50 tw:focus:ring-purple-500/40 tw:dark:bg-gray-800 tw:dark:text-gray-100 tw:dark:border-gray-700 tw:dark:hover:border-purple-500 tw:dark:hover:bg-purple-950",
        link: "twlink tw:p-0"
      }.freeze

      # The active look, as a delta over COLORS — always emitted alongside it and inert
      # until the element flags itself active (see the is-active variant in application.css,
      # which sorts last, so these override the resting colors with no `!` important).
      # Literal strings so Tailwind's scanner generates them; the spec enforces the prefix.
      ACTIVE_COLORS = {
        primary: "tw:is-active:bg-blue-700 tw:is-active:ring-2 tw:is-active:ring-blue-500/40 tw:is-active:dark:bg-blue-600",
        secondary: "tw:is-active:bg-gray-200 tw:is-active:border-gray-400 tw:is-active:ring-2 tw:is-active:ring-blue-500/40 tw:is-active:dark:bg-gray-800",
        error: "tw:is-active:bg-red-700 tw:is-active:ring-2 tw:is-active:ring-red-500/40 tw:is-active:dark:bg-red-600",
        purple: "tw:is-active:bg-purple-600 tw:is-active:border-purple-600 tw:is-active:ring-2 tw:is-active:ring-purple-500/40",
        danger_outline: "tw:is-active:bg-red-100 tw:is-active:border-[#c0392b] tw:is-active:ring-2 tw:is-active:ring-red-500/40 tw:is-active:dark:bg-red-950 tw:is-active:dark:border-red-700",
        purple_outline: "tw:is-active:text-white tw:is-active:bg-purple-500 tw:is-active:border-purple-500 tw:is-active:ring-2 tw:is-active:ring-purple-500/40",
        link: "tw:is-active:text-blue-700 tw:is-active:dark:text-blue-300 tw:is-active:font-bold tw:is-active:underline"
      }.freeze

      KINDS = %i[button submit]

      DISABLED_CLASSES = "tw:disabled:opacity-50 tw:disabled:cursor-not-allowed tw:disabled:pointer-events-none"

      # is-active sorts after focus, so an active button's ring-2 swallows the focus ring
      # unless focus is restated under the variant.
      FOCUS_CLASSES = "tw:focus:outline-none tw:focus:ring-3 tw:is-active:focus:ring-3"

      def self.build_classes(color:, size:, html_class: nil)
        unless color == :link
          extras = [SIZES[size], FOCUS_CLASSES, "tw:font-medium tw:no-underline", DISABLED_CLASSES]
        end
        [BASE_CLASSES, html_class, *extras, COLORS[color], ACTIVE_COLORS[color]].compact.join(" ")
      end

      def initialize(text: nil, color: :secondary, size: :md, active: false, html_class: nil, kind: nil, disabled: false, spinner: false, data: {}, aria: {})
        @text = text
        @color = COLORS.key?(color) ? color : :secondary
        @kind = KINDS.include?(kind&.to_sym) ? kind.to_sym : KINDS.first
        @active = active
        @html_class = html_class
        @disabled = disabled
        @spinner = spinner
        @data = data
        @aria = aria

        @size = SIZES.key?(size) ? size : :md
        raise ArgumentError, "size is not supported for link color" if @color == :link && @size != :md
      end

      def call
        content_tag(:button, button_content, class: button_classes, type: (@kind == :submit) ? "submit" : "button", disabled: @disabled, data: button_data, aria: @aria)
      end

      def button_classes
        self.class.build_classes(color: @color, size: @size, html_class: @html_class)
      end

      private

      def button_data
        data = @data.merge(active: @active || nil)
        return data unless @spinner

        data.merge(controller: [data[:controller], "ui--buttons--submit-spinner"].compact.join(" "))
      end

      def button_content
        return @text || content unless @spinner

        # Hidden until the submit-spinner controller reveals it on form submit;
        # no color_class so the svg spins in the button's own text color.
        spinner = content_tag(:span, render(UI::LoadingSpinner::Component.new(size: :sm, color_class: "")),
          class: "tw:hidden", data: {"ui--buttons--submit-spinner-target": "spinner"})
        safe_join([spinner, @text || content])
      end
    end
  end
end
