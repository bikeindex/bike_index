# frozen_string_literal: true

module UI
  module LoadingSpinner
    class Component < ApplicationComponent
      SIZES = {
        sm: "tw:h-3 tw:w-3",
        md: "tw:h-15 tw:w-15"
      }.freeze

      # A nil color_class leaves the svg inheriting currentColor from its surroundings
      def initialize(text: nil, size: :md, color_class: "tw:text-slate-400 tw:dark:text-blue-800")
        @text = text
        @size = SIZES.key?(size) ? size : :md
        @color_class = color_class
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
        classes = ["tw:animate-spin", @color_class.presence, SIZES[@size]].compact.join(" ")
        classes = "tw:inline #{classes}" if inline?
        classes = "tw:mx-auto tw:mt-4 #{classes}" unless inline?

        helpers.inline_svg_tag("kelsey/illustrations/bike_wheel.svg", class: classes, aria_hidden: true)
      end
    end
  end
end
