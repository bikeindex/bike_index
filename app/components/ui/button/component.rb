# frozen_string_literal: true

module UI
  module Button
    # Renders a <button>. For a link styled as a button, or an action button that
    # submits a request to a URL (button_to), use UI::ButtonLink instead — it reuses
    # this component's build_classes, so the two stay visually in lockstep.
    class Component < ApplicationComponent
      BASE_CLASSES = "tw:inline-flex tw:items-center tw:gap-1.5 tw:rounded-lg tw:cursor-pointer tw:transition-colors"

      SIZES = {
        sm: "tw:px-2.5 tw:py-1 tw:text-xs",
        md: "tw:px-3 tw:py-1.5 tw:text-sm",
        lg: "tw:px-4 tw:py-2 tw:text-base"
      }.freeze

      COLORS = {
        primary: "tw:text-white tw:bg-blue-600 tw:border tw:border-blue-600 tw:hover:bg-blue-700 tw:active:bg-blue-800 tw:focus:ring-blue-500/40 tw:dark:bg-blue-500 tw:dark:border-blue-500 tw:dark:hover:bg-blue-600 tw:dark:active:bg-blue-700",
        secondary: "tw:text-gray-800 tw:bg-white tw:border tw:border-gray-300 tw:hover:bg-gray-50 tw:hover:border-gray-400 tw:active:bg-gray-100 tw:focus:ring-blue-500/40 tw:dark:bg-transparent tw:dark:text-gray-100 tw:dark:border-gray-600 tw:dark:hover:bg-gray-800",
        error: "tw:text-white tw:bg-red-600 tw:border tw:border-red-600 tw:hover:bg-red-700 tw:active:bg-red-800 tw:focus:ring-red-500/40 tw:dark:bg-red-500 tw:dark:border-red-500 tw:dark:hover:bg-red-600 tw:dark:active:bg-red-700",
        purple: "tw:text-white tw:bg-purple-500 tw:border tw:border-purple-500 tw:hover:bg-purple-600 tw:hover:border-purple-600 tw:active:bg-purple-600 tw:focus:ring-purple-500/40",
        danger_outline: "tw:text-[#c0392b] tw:bg-white tw:border tw:border-[#f3c9c9] tw:hover:bg-red-50 tw:active:bg-red-100 tw:focus:ring-red-500/40 tw:dark:bg-transparent tw:dark:text-red-400 tw:dark:border-red-900 tw:dark:hover:bg-red-950",
        purple_outline: "tw:text-gray-800 tw:bg-white tw:border tw:border-gray-200 tw:hover:border-purple-500 tw:hover:bg-purple-50 tw:focus:ring-purple-500/40 tw:dark:bg-gray-800 tw:dark:text-gray-100 tw:dark:border-gray-700 tw:dark:hover:border-purple-500 tw:dark:hover:bg-purple-950",
        link: "twlink tw:p-0"
      }.freeze

      # The complete color set for the persistent active: true state. build_classes
      # emits this *instead of* COLORS (see there), so resting and active fills never
      # coexist and no `!` important is needed to settle the cascade. link is the
      # exception — it layers over COLORS[:link] since `twlink` isn't variant-able.
      ACTIVE_COLORS = {
        primary: "tw:text-white tw:bg-blue-700 tw:border tw:border-blue-600 tw:ring-2 tw:ring-blue-500/40 tw:dark:bg-blue-600 tw:dark:border-blue-500",
        secondary: "tw:text-gray-800 tw:bg-gray-200 tw:border tw:border-gray-400 tw:ring-2 tw:ring-blue-500/40 tw:dark:text-gray-100 tw:dark:bg-gray-800 tw:dark:border-gray-600",
        error: "tw:text-white tw:bg-red-700 tw:border tw:border-red-600 tw:ring-2 tw:ring-red-500/40 tw:dark:bg-red-600 tw:dark:border-red-500",
        danger_outline: "tw:text-[#c0392b] tw:bg-red-100 tw:border tw:border-[#c0392b] tw:ring-2 tw:ring-red-500/40 tw:dark:text-red-400 tw:dark:bg-red-950 tw:dark:border-red-700",
        purple: "tw:text-white tw:bg-purple-600 tw:border tw:border-purple-600 tw:ring-2 tw:ring-purple-500/40",
        purple_outline: "tw:text-white tw:bg-purple-500 tw:border tw:border-purple-500 tw:ring-2 tw:ring-purple-500/40",
        link: "tw:text-blue-800 tw:dark:text-blue-300 tw:font-bold tw:underline"
      }.freeze

      # A mirror of ACTIVE_COLORS under aria-pressed:/active: — so a resting button shows
      # the active look while pressed or toggled, without being passed active: true. Kept
      # as literal strings so Tailwind's scanner generates the variants (see spec, which
      # enforces the mirror). These are variants, so they win over COLORS by precedence.
      ACTIVE_PREFIXED = {
        primary: "tw:aria-pressed:text-white tw:active:text-white tw:aria-pressed:bg-blue-700 tw:active:bg-blue-700 tw:aria-pressed:border tw:active:border tw:aria-pressed:border-blue-600 tw:active:border-blue-600 tw:aria-pressed:ring-2 tw:active:ring-2 tw:aria-pressed:ring-blue-500/40 tw:active:ring-blue-500/40 tw:aria-pressed:dark:bg-blue-600 tw:active:dark:bg-blue-600 tw:aria-pressed:dark:border-blue-500 tw:active:dark:border-blue-500",
        secondary: "tw:aria-pressed:text-gray-800 tw:active:text-gray-800 tw:aria-pressed:bg-gray-200 tw:active:bg-gray-200 tw:aria-pressed:border tw:active:border tw:aria-pressed:border-gray-400 tw:active:border-gray-400 tw:aria-pressed:ring-2 tw:active:ring-2 tw:aria-pressed:ring-blue-500/40 tw:active:ring-blue-500/40 tw:aria-pressed:dark:text-gray-100 tw:active:dark:text-gray-100 tw:aria-pressed:dark:bg-gray-800 tw:active:dark:bg-gray-800 tw:aria-pressed:dark:border-gray-600 tw:active:dark:border-gray-600",
        error: "tw:aria-pressed:text-white tw:active:text-white tw:aria-pressed:bg-red-700 tw:active:bg-red-700 tw:aria-pressed:border tw:active:border tw:aria-pressed:border-red-600 tw:active:border-red-600 tw:aria-pressed:ring-2 tw:active:ring-2 tw:aria-pressed:ring-red-500/40 tw:active:ring-red-500/40 tw:aria-pressed:dark:bg-red-600 tw:active:dark:bg-red-600 tw:aria-pressed:dark:border-red-500 tw:active:dark:border-red-500",
        danger_outline: "tw:aria-pressed:text-[#c0392b] tw:active:text-[#c0392b] tw:aria-pressed:bg-red-100 tw:active:bg-red-100 tw:aria-pressed:border tw:active:border tw:aria-pressed:border-[#c0392b] tw:active:border-[#c0392b] tw:aria-pressed:ring-2 tw:active:ring-2 tw:aria-pressed:ring-red-500/40 tw:active:ring-red-500/40 tw:aria-pressed:dark:text-red-400 tw:active:dark:text-red-400 tw:aria-pressed:dark:bg-red-950 tw:active:dark:bg-red-950 tw:aria-pressed:dark:border-red-700 tw:active:dark:border-red-700",
        purple: "tw:aria-pressed:text-white tw:active:text-white tw:aria-pressed:bg-purple-600 tw:active:bg-purple-600 tw:aria-pressed:border tw:active:border tw:aria-pressed:border-purple-600 tw:active:border-purple-600 tw:aria-pressed:ring-2 tw:active:ring-2 tw:aria-pressed:ring-purple-500/40 tw:active:ring-purple-500/40",
        purple_outline: "tw:aria-pressed:text-white tw:active:text-white tw:aria-pressed:bg-purple-500 tw:active:bg-purple-500 tw:aria-pressed:border tw:active:border tw:aria-pressed:border-purple-500 tw:active:border-purple-500 tw:aria-pressed:ring-2 tw:active:ring-2 tw:aria-pressed:ring-purple-500/40 tw:active:ring-purple-500/40",
        link: "tw:aria-pressed:text-blue-800 tw:active:text-blue-800 tw:aria-pressed:dark:text-blue-300 tw:active:dark:text-blue-300 tw:aria-pressed:font-bold tw:active:font-bold tw:aria-pressed:underline tw:active:underline"
      }.freeze

      KINDS = %i[button submit]

      DISABLED_CLASSES = "tw:disabled:opacity-50 tw:disabled:cursor-not-allowed tw:disabled:pointer-events-none"

      def self.build_classes(color:, size:, active: false, html_class: nil)
        classes = [BASE_CLASSES, html_class]
        if color == :link
          # twlink isn't variant-able, so link layers the active delta over its resting base.
          classes << COLORS[color]
          classes << ACTIVE_COLORS[color] if active
        else
          classes << SIZES[size]
          classes << "tw:focus:outline-none tw:focus:ring-3 tw:font-medium tw:no-underline"
          classes << DISABLED_CLASSES
          classes << (active ? ACTIVE_COLORS[color] : COLORS[color])
        end
        classes << ACTIVE_PREFIXED[color]
        classes.compact.join(" ")
      end

      def initialize(text: nil, color: :secondary, size: :md, active: false, html_class: nil, kind: nil, disabled: false, data: {}, aria: {})
        @text = text
        @color = COLORS.key?(color) ? color : :secondary
        @kind = KINDS.include?(kind&.to_sym) ? kind.to_sym : KINDS.first
        @active = active
        @html_class = html_class
        @disabled = disabled
        @data = data
        @aria = aria

        @size = SIZES.key?(size) ? size : :md
        raise ArgumentError, "size is not supported for link color" if @color == :link && @size != :md
      end

      def call
        content_tag(:button, @text || content, class: button_classes, type: (@kind == :submit) ? "submit" : "button", disabled: @disabled, data: @data, aria: @aria)
      end

      def button_classes
        self.class.build_classes(color: @color, size: @size, active: @active, html_class: @html_class)
      end
    end
  end
end
