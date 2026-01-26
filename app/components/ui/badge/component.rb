# frozen_string_literal: true

module UI::Badge
  class Component < ApplicationComponent
    BASE_CLASSES = "tw:ml-1 tw:inline-block tw:text-white tw:text-[75%] tw:font-extrabold tw:px-1 tw:py-0.5 tw:border tw:border-gray-300 tw:leading-none tw:rounded-lg tw:cursor-default"

    COLORS = {
      emerald: "tw:bg-emerald-500",
      blue: "tw:bg-blue-600",
      purple: "tw:bg-purple-800",
      amber: "tw:bg-amber-400",
      cyan: "tw:bg-cyan-600",
      red: "tw:bg-red-500",
      red_light: "tw:bg-red-400",
      gray: "tw:bg-gray-500"
    }.freeze

    def initialize(text:, color: :gray, title: nil)
      @text = text
      @title = title || text
      @color = COLORS.key?(color) ? color : :gray
    end

    def badge_classes
      [BASE_CLASSES, COLORS[@color]].join(" ")
    end
  end
end
