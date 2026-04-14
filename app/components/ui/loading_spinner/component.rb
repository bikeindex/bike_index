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

    def call
      if inline?
        spinner_svg
      else
        content_tag(:div, class: "tw:animate-pulse tw:justify-center tw:p-6 tw:text-center") do
          safe_join([content_tag(:p, @text, class: "tw:text-lg"), spinner_svg])
        end
      end
    end

    def inline?
      @text.blank?
    end

    private

    def spinner_svg
      classes = "tw:animate-spin tw:text-slate-400 tw:dark:text-blue-800 #{SIZES[@size]}"
      classes = "tw:inline #{classes}" if inline?
      classes = "tw:mx-auto tw:mt-4 #{classes}" unless inline?

      content_tag(:svg, class: classes, xmlns: "http://www.w3.org/2000/svg",
        fill: "none", viewBox: "0 0 24 24") do
        safe_join([
          tag.circle(class: "tw:opacity-25", cx: "12", cy: "12", r: "10",
            stroke: "currentColor", "stroke-width": "4"),
          tag.path(class: "tw:opacity-75", fill: "currentColor",
            d: "M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z")
        ])
      end
    end
  end
end
