# frozen_string_literal: true

module Register
  module AcknowledgmentProgress
    # The eyebrow above each acknowledgment step, counting the review the pages end at
    # as the last one
    class Component < ApplicationComponent
      def initialize(sequence:, number:, total:)
        @sequence = sequence
        @number = number
        @total = total
      end

      def call
        content_tag(:p, class: "tw:mb-4 tw:flex tw:items-center tw:gap-1.5 tw:text-xs tw:font-bold tw:text-gray-500 tw:dark:text-gray-400") do
          safe_join([
            helpers.inline_svg_tag("icons/check.svg", class: "tw:h-3.5 tw:w-3.5 tw:shrink-0 tw:text-green-600", aria_hidden: true),
            translation(".progress_saved.#{@sequence.kind}", number: @number, total: @total)
          ], " ")
        end
      end
    end
  end
end
