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

      # Hover is guarded against both ways an element says it's disabled — :disabled for a
      # button, aria-disabled for UI::ButtonLink's anchor. Nothing else stops it now.
      COLORS = {
        primary: "tw:text-white tw:bg-blue-600 tw:border tw:border-blue-600 tw:not-disabled:not-aria-disabled:hover:bg-blue-700 tw:focus:ring-blue-500/40 tw:dark:bg-blue-500 tw:dark:border-blue-500 tw:dark:not-disabled:not-aria-disabled:hover:bg-blue-600",
        secondary: "tw:text-gray-800 tw:bg-white tw:border tw:border-gray-200 tw:not-disabled:not-aria-disabled:hover:border-purple-500 tw:not-disabled:not-aria-disabled:hover:bg-purple-50 tw:focus:ring-purple-500/40 tw:dark:bg-gray-800 tw:dark:text-gray-100 tw:dark:border-gray-700 tw:dark:not-disabled:not-aria-disabled:hover:border-purple-500 tw:dark:not-disabled:not-aria-disabled:hover:bg-purple-950",
        error: "tw:text-[#c0392b] tw:bg-white tw:border tw:border-[#f3c9c9] tw:not-disabled:not-aria-disabled:hover:bg-red-50 tw:focus:ring-red-500/40 tw:dark:bg-transparent tw:dark:text-red-400 tw:dark:border-red-900 tw:dark:not-disabled:not-aria-disabled:hover:bg-red-950",
        purple: "tw:text-white tw:bg-purple-500 tw:border tw:border-purple-500 tw:not-disabled:not-aria-disabled:hover:bg-purple-600 tw:not-disabled:not-aria-disabled:hover:border-purple-600 tw:focus:ring-purple-500/40",
        link: "twlink tw:p-0 tw:focus:ring-blue-500/40"
      }.freeze

      # The active look, as a delta over COLORS — always emitted alongside it and inert
      # until the element flags itself active (see the is-active variant in application.css,
      # which sorts last, so these override the resting colors with no `!` important).
      # Literal strings so Tailwind's scanner generates them; the spec enforces the prefix.
      #
      # No :link — .twlink states its own active look under the same variant, and a utility
      # here would win over it, so link color would stop following the class it's built from.
      ACTIVE_COLORS = {
        primary: "tw:is-active:bg-blue-800 tw:is-active:ring-2 tw:is-active:ring-blue-500/40 tw:is-active:dark:bg-blue-700",
        secondary: "tw:is-active:text-white tw:is-active:bg-purple-500 tw:is-active:border-purple-500 tw:is-active:ring-2 tw:is-active:ring-purple-500/40",
        error: "tw:is-active:bg-red-100 tw:is-active:border-[#c0392b] tw:is-active:ring-2 tw:is-active:ring-red-500/40 tw:is-active:dark:bg-red-950 tw:is-active:dark:border-red-700",
        purple: "tw:is-active:bg-purple-700 tw:is-active:border-purple-700 tw:is-active:ring-2 tw:is-active:ring-purple-500/40"
      }.freeze

      # No pointer-events-none: with pointer events off the browser takes the cursor from
      # underneath, so not-allowed never shows. The aria-disabled half dims ButtonLink's
      # anchor; each half is inert on the element the other covers.
      DISABLED_CLASSES = "tw:disabled:opacity-50 tw:disabled:cursor-not-allowed tw:aria-disabled:opacity-50 tw:aria-disabled:cursor-not-allowed"

      # is-active sorts after focus, so an active button's ring-2 swallows the focus ring
      # unless focus is restated under the variant.
      FOCUS_CLASSES = "tw:focus:outline-none tw:focus:ring-3 tw:is-active:focus:ring-3"

      # Focus and disabled reach link color too — only the sizing and weight are
      # button-shaped
      def self.build_classes(color:, size:, html_class: nil)
        extras = [FOCUS_CLASSES, DISABLED_CLASSES]
        extras += [SIZES[size], "tw:font-medium tw:no-underline"] unless color == :link
        [BASE_CLASSES, html_class, *extras, COLORS[color], ACTIVE_COLORS[color]].compact.join(" ")
      end

      # ButtonLink calls this too, so the pair answers a caller the same way
      def self.validate_options!(color:, size:, html_options:)
        raise ArgumentError, "unknown color #{color.inspect}, expected one of: #{COLORS.keys.join(", ")}" unless COLORS.key?(color)
        raise ArgumentError, "size is not supported for link color" if color == :link && size != :md
        # The component builds its own class, so a passed one is dropped rather than merged
        raise ArgumentError, "class is not supported, you must use the keyword arg html_class" if html_options.key?(:class)
      end

      # name/value are submitted with the form when this button is the one clicked, which
      # is how a form with more than one submit says which was pressed
      def initialize(text: nil, color: :secondary, size: :md, active: false, html_class: nil, spinner: false, name: nil, value: nil, **html_options)
        @text = text
        @name = name
        @value = value
        @color = color
        @active = active
        @html_class = html_class
        @spinner = spinner
        @type = html_options.delete(:type) || "button"
        @data = html_options.delete(:data) || {}
        @html_options = html_options

        @size = SIZES.key?(size) ? size : :md
        self.class.validate_options!(color: @color, size: @size, html_options:)
      end

      # html_options lead, so the component's own attributes can't be overwritten
      def call
        content_tag(:button, safe_join([spinner_span, @text || content].compact), **@html_options, type: @type, class: button_classes, name: @name, value: @value, data: button_data)
      end

      def button_classes
        self.class.build_classes(color: @color, size: @size, html_class: @html_class)
      end

      private

      def button_data
        data = @data.merge(active: @active || nil)
        return data unless @spinner

        data.merge(controller: [data[:controller], "ui--button--submit-spinner"].compact.join(" "))
      end

      # Hidden until the submit-spinner controller reveals it on form submit;
      # no color_class so the svg spins in the button's own text color.
      def spinner_span
        return unless @spinner

        content_tag(:span, render(UI::LoadingSpinner::Component.new(size: :sm, color_class: nil)),
          class: "tw:hidden", data: {"ui--button--submit-spinner-target": "spinner"})
      end
    end
  end
end
