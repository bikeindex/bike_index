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
        purple: "tw:text-white tw:bg-[#715eb2] tw:border tw:border-[#715eb2] tw:hover:bg-[#5d4b9c] tw:hover:border-[#5d4b9c] tw:active:bg-[#5d4b9c] tw:focus:ring-[#715eb2]/40",
        danger_outline: "tw:text-[#c0392b] tw:bg-white tw:border tw:border-[#f3c9c9] tw:hover:bg-red-50 tw:active:bg-red-100 tw:focus:ring-red-500/40 tw:dark:bg-transparent tw:dark:text-red-400 tw:dark:border-red-900 tw:dark:hover:bg-red-950",
        purple_outline: "tw:text-gray-800 tw:bg-white tw:border tw:border-gray-200 tw:hover:border-[#715eb2] tw:hover:bg-[#f7f5fc] tw:focus:ring-[#715eb2]/40 tw:dark:bg-gray-800 tw:dark:text-gray-100 tw:dark:border-gray-700 tw:dark:hover:border-[#715eb2] tw:dark:hover:bg-purple-950",
        link: "twlink tw:p-0"
      }.freeze

      ACTIVE_COLORS = {
        primary: "tw:ring-2 tw:ring-blue-500/40 tw:bg-blue-700 tw:dark:bg-blue-600",
        secondary: "tw:ring-2 tw:ring-blue-500/40 tw:bg-gray-200 tw:border-gray-400 tw:dark:bg-gray-800 tw:dark:border-gray-600",
        error: "tw:ring-2 tw:ring-red-500/40 tw:bg-red-700 tw:dark:bg-red-600",
        danger_outline: "tw:ring-2 tw:ring-red-500/40 tw:bg-red-100 tw:border-[#c0392b] tw:dark:bg-red-950 tw:dark:border-red-700",
        purple: "tw:ring-2 tw:ring-[#715eb2]/40 tw:bg-[#5d4b9c]",
        purple_outline: "tw:ring-2 tw:ring-[#715eb2]/40 tw:bg-[#715eb2] tw:text-white tw:border-[#715eb2]",
        link: "tw:text-blue-800 tw:dark:text-blue-300 tw:font-bold tw:underline"
      }.freeze

      # Literal strings so Tailwind's scanner generates these aria-pressed:/active: variants.
      ACTIVE_PREFIXED = {
        primary: "tw:aria-pressed:ring-2 tw:active:ring-2 tw:aria-pressed:ring-blue-500/40 tw:active:ring-blue-500/40 tw:aria-pressed:bg-blue-700 tw:active:bg-blue-700 tw:aria-pressed:dark:bg-blue-600 tw:active:dark:bg-blue-600",
        secondary: "tw:aria-pressed:ring-2 tw:active:ring-2 tw:aria-pressed:ring-blue-500/40 tw:active:ring-blue-500/40 tw:aria-pressed:bg-gray-200 tw:active:bg-gray-200 tw:aria-pressed:border-gray-400 tw:active:border-gray-400 tw:aria-pressed:dark:bg-gray-800 tw:active:dark:bg-gray-800 tw:aria-pressed:dark:border-gray-600 tw:active:dark:border-gray-600",
        error: "tw:aria-pressed:ring-2 tw:active:ring-2 tw:aria-pressed:ring-red-500/40 tw:active:ring-red-500/40 tw:aria-pressed:bg-red-700 tw:active:bg-red-700 tw:aria-pressed:dark:bg-red-600 tw:active:dark:bg-red-600",
        danger_outline: "tw:aria-pressed:ring-2 tw:active:ring-2 tw:aria-pressed:ring-red-500/40 tw:active:ring-red-500/40 tw:aria-pressed:bg-red-100 tw:active:bg-red-100 tw:aria-pressed:border-[#c0392b] tw:active:border-[#c0392b] tw:aria-pressed:dark:bg-red-950 tw:active:dark:bg-red-950 tw:aria-pressed:dark:border-red-700 tw:active:dark:border-red-700",
        purple: "tw:aria-pressed:ring-2 tw:active:ring-2 tw:aria-pressed:ring-[#715eb2]/40 tw:active:ring-[#715eb2]/40 tw:aria-pressed:bg-[#5d4b9c] tw:active:bg-[#5d4b9c]",
        purple_outline: "tw:aria-pressed:ring-2 tw:active:ring-2 tw:aria-pressed:ring-[#715eb2]/40 tw:active:ring-[#715eb2]/40 tw:aria-pressed:bg-[#715eb2] tw:active:bg-[#715eb2] tw:aria-pressed:text-white tw:active:text-white tw:aria-pressed:border-[#715eb2] tw:active:border-[#715eb2]",
        link: "tw:aria-pressed:text-blue-800 tw:active:text-blue-800 tw:aria-pressed:dark:text-blue-300 tw:active:dark:text-blue-300 tw:aria-pressed:font-bold tw:active:font-bold tw:aria-pressed:underline tw:active:underline"
      }.freeze

      KINDS = %i[button submit]

      DISABLED_CLASSES = "tw:disabled:opacity-50 tw:disabled:cursor-not-allowed tw:disabled:pointer-events-none"

      def self.build_classes(color:, size:, active: false, html_class: nil)
        classes = [BASE_CLASSES, COLORS[color], html_class]
        unless color == :link
          classes << SIZES[size]
          classes << "tw:focus:outline-none tw:focus:ring-3 tw:font-medium tw:no-underline"
          classes << DISABLED_CLASSES
        end
        classes << ACTIVE_COLORS[color] if active
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
