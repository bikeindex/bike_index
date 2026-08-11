# frozen_string_literal: true

module UI
  module Badge
    class Component < ApplicationComponent
      BASE_CLASSES = "tw:inline-flex tw:border tw:items-center tw:leading-4 tw:rounded-full"

      SIZES = {
        xs: "tw:text-[11px] tw:font-semibold tw:px-[7px] tw:py-px",
        sm: "tw:text-xs tw:font-medium tw:px-1 tw:py-px",
        md: "tw:text-xs tw:font-bold tw:px-2 tw:py-1",
        lg: "tw:text-md tw:font-extrabold tw:px-3 tw:py-1"
      }

      # Soft tinted pills matching the redesign: light background + saturated text
      COLORS = {
        notice: "tw:bg-blue-50 tw:text-blue-700 tw:border-transparent tw:dark:bg-blue-950 tw:dark:text-blue-200",
        error: "tw:bg-red-50 tw:text-red-700 tw:border-transparent tw:dark:bg-red-950 tw:dark:text-red-200",
        warning: "tw:bg-amber-50 tw:text-amber-700 tw:border-transparent tw:dark:bg-amber-950 tw:dark:text-amber-200",
        success: "tw:bg-green-50 tw:text-green-700 tw:border-transparent tw:dark:bg-green-950 tw:dark:text-green-200",
        # Special badge classes:
        cyan: "tw:bg-cyan-50 tw:text-cyan-700 tw:border-transparent tw:dark:bg-cyan-950 tw:dark:text-cyan-200",
        # The redesign's quiet pill. Text is --redesign-gray-500 rather than the
        # mockup's #9a9aa2, which sat at 2.45:1 on this background.
        gray: "tw:bg-[#f0f0f2] tw:text-[#666666] tw:border-transparent tw:dark:bg-gray-800 tw:dark:text-gray-400",
        purple: "tw:bg-purple-50 tw:text-purple-700 tw:border-transparent tw:dark:bg-purple-950 tw:dark:text-purple-200",
        rose: "tw:bg-rose-50 tw:text-rose-700 tw:border-transparent tw:dark:bg-rose-950 tw:dark:text-rose-200",
        orange: "tw:bg-orange-50 tw:text-orange-700 tw:border-transparent tw:dark:bg-orange-950 tw:dark:text-orange-200",
        empty: "tw:bg-white tw:text-gray-700 tw:border-gray-300 tw:dark:bg-gray-900 tw:dark:text-gray-200 tw:dark:border-gray-600"
      }.freeze

      # Solid pills (saturated background + white text) — e.g. the redesign audience pill
      SOLID_COLORS = {
        notice: "tw:bg-blue-500 tw:text-white tw:border-transparent",
        error: "tw:bg-red-600 tw:text-white tw:border-transparent",
        warning: "tw:bg-amber-500 tw:text-white tw:border-transparent",
        success: "tw:bg-green-600 tw:text-white tw:border-transparent",
        cyan: "tw:bg-cyan-500 tw:text-white tw:border-transparent",
        gray: "tw:bg-gray-500 tw:text-white tw:border-transparent",
        purple: "tw:bg-purple-500 tw:text-white tw:border-transparent",
        rose: "tw:bg-rose-500 tw:text-white tw:border-transparent",
        orange: "tw:bg-orange-500 tw:text-white tw:border-transparent",
        empty: "tw:bg-gray-500 tw:text-white tw:border-transparent"
      }.freeze

      def self.badge_classes(color:, size:, cursor: "tw:cursor-default", solid: false)
        palette = solid ? SOLID_COLORS : COLORS
        [BASE_CLASSES, cursor, palette[color], SIZES[size]].join(" ")
      end

      def initialize(text:, title: nil, color: :gray, size: :md, indicator: false, solid: false, icon: nil)
        @text = text
        @title = title
        @color = COLORS.key?(color) ? color : :gray
        @size = SIZES.include?(size) ? size : :md
        @indicator = indicator
        @solid = solid
        @icon = icon
      end

      def call
        leading = leading_element
        label = content.presence || @text
        label = safe_join([leading, label]) if leading
        badge = content_tag(:span, label, class: badge_class)
        return badge unless custom_title?
        render(UI::Tooltip::Component.new(text: @title)) { badge }
      end

      private

      # An inline icon (@icon is a path under app/assets/images, sans .svg) takes
      # precedence over the status dot. Both are decorative - the badge's text is
      # its accessible name - so they stay out of the accessibility tree.
      def leading_element
        return helpers.inline_svg_tag("#{@icon}.svg", class: "tw:mr-1 tw:size-3.5", aria_hidden: true) if @icon.present?
        indicator_dot if @indicator
      end

      # A small status dot inheriting the badge's text color
      def indicator_dot
        content_tag(:span, "", class: "tw:mr-1.5 tw:inline-block tw:size-1.5 tw:rounded-full tw:bg-current", aria: {hidden: true})
      end

      def custom_title?
        @title.present? && @title != @text
      end

      def badge_class
        self.class.badge_classes(color: @color, size: @size, solid: @solid, cursor: custom_title? ? "tw:cursor-help" : "tw:cursor-default")
      end
    end
  end
end
