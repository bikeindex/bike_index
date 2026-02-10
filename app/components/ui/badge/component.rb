# frozen_string_literal: true

module UI::Badge
  class Component < ApplicationComponent
    BASE_CLASSES = "tw:inline-flex tw:border tw:items-center tw:leading-4 tw:rounded-full tw:cursor-default"

    SIZES = {
      sm: "tw:text-xs tw:font-medium tw:px-1 tw:py-px",
      md: "tw:text-xs tw:font-bold tw:px-2 tw:py-1",
      lg: "tw:text-md tw:font-extrabold tw:px-3 tw:py-1"
    }

    COLORS = {
      notice: "tw:bg-blue-300 tw:text-blue-900 tw:dark:bg-blue-800 tw:dark:text-blue-200",
      error: "tw:bg-red-300 tw:text-red-950 tw:dark:bg-red-800 tw:dark:text-red-300",
      warning: "tw:bg-amber-300 tw:text-amber-900 tw:dark:bg-amber-800 tw:dark:text-amber-200",
      success: "tw:bg-emerald-500 tw:text-emerald-900 tw:dark:bg-emerald-800 tw:dark:text-emerald-200",
      # Special badge classes:
      cyan: "tw:bg-cyan-400 tw:text-cyan-900 tw:dark:bg-cyan-800 tw:dark:text-cyan-200",
      gray: "tw:bg-gray-300 tw:text-gray-900 tw:dark:bg-gray-700 tw:dark:text-gray-200",
      purple: "tw:bg-purple-300 tw:text-purple-900 tw:dark:bg-purple-800 tw:dark:text-purple-200"

    }.freeze

    def initialize(text:, title: nil, color: :gray, size: :md)
      @text = text
      @title = title || text
      @color = COLORS.key?(color) ? color : :gray
      @size = SIZES.include?(size) ? size : :md
    end

    private

    def badge_classes
      [
        BASE_CLASSES,
        COLORS[@color],
        SIZES[@size]
      ].join(" ")
    end
  end
end
