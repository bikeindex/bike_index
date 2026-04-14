# frozen_string_literal: true

module UI::LoadingSpinner
  class Component < ApplicationComponent
    SIZES = {
      sm: "tw:h-3 tw:w-3",
      md: "tw:h-15 tw:w-15"
    }.freeze

    def initialize(text: nil, size: :md)
      @text = text
      @size = SIZES.key?(size) ? size : :md
    end

    def inline?
      @text.blank?
    end

    def svg_classes
      base = "tw:animate-spin tw:text-slate-400 tw:dark:text-blue-800"
      if inline?
        "tw:inline #{base} #{SIZES[@size]}"
      else
        "tw:mx-auto tw:mt-4 #{base} #{SIZES[@size]}"
      end
    end
  end
end
