# frozen_string_literal: true

module UI
  module Badge
    class Component < ApplicationComponent
      BASE_CLASSES = "tw:inline-flex tw:border tw:items-center tw:leading-4 tw:rounded-full"

      SIZES = {
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
        gray: "tw:bg-gray-100 tw:text-gray-700 tw:border-transparent tw:dark:bg-gray-800 tw:dark:text-gray-200",
        purple: "tw:bg-purple-50 tw:text-purple-700 tw:border-transparent tw:dark:bg-purple-950 tw:dark:text-purple-200",
        rose: "tw:bg-rose-50 tw:text-rose-700 tw:border-transparent tw:dark:bg-rose-950 tw:dark:text-rose-200",
        orange: "tw:bg-orange-50 tw:text-orange-700 tw:border-transparent tw:dark:bg-orange-950 tw:dark:text-orange-200",
        empty: "tw:bg-white tw:text-gray-700 tw:border-gray-300 tw:dark:bg-gray-900 tw:dark:text-gray-200 tw:dark:border-gray-600"
      }.freeze

      def self.badge_classes(color:, size:, cursor: "tw:cursor-default")
        [BASE_CLASSES, cursor, COLORS[color], SIZES[size]].join(" ")
      end

      def initialize(text:, title: nil, color: :gray, size: :md, indicator: false)
        @text = text
        @title = title
        @color = COLORS.key?(color) ? color : :gray
        @size = SIZES.include?(size) ? size : :md
        @indicator = indicator
      end

      def call
        label = content.presence || @text
        label = safe_join([indicator_dot, label]) if @indicator
        badge = content_tag(:span, label, class: badge_class)
        return badge unless custom_title?
        render(UI::Tooltip::Component.new(text: @title)) { badge }
      end

      private

      # A small status dot inheriting the badge's text color
      def indicator_dot
        content_tag(:span, "", class: "tw:mr-1.5 tw:inline-block tw:size-1.5 tw:rounded-full tw:bg-current")
      end

      def custom_title?
        @title.present? && @title != @text
      end

      def badge_class
        self.class.badge_classes(color: @color, size: @size, cursor: custom_title? ? "tw:cursor-help" : "tw:cursor-default")
      end
    end
  end
end
