# frozen_string_literal: true

module UI
  module Container
    # A single column of labelled inputs stops being readable before a wide screen runs
    # out - the eye has to cross empty space from the label to its field - so a form that
    # needs more room splits into columns rather than growing. The page owns its gutter
    # (.twgutter); this only caps width, so containers nest without doubling padding.
    class Component < ApplicationComponent
      MAX_WIDTHS = {1 => "tw:max-w-3xl", 2 => "tw:max-w-7xl"}.freeze
      COLUMNS = MAX_WIDTHS.keys.freeze
      ALIGNMENTS = %i[center left].freeze

      def initialize(columns: 1, alignment: :center)
        raise_if_invalid_value!(:columns, columns, COLUMNS)
        raise_if_invalid_value!(:alignment, alignment, ALIGNMENTS)

        @columns = columns
        @alignment = alignment
      end

      def call = tag.div(content, class: classes)

      private

      def classes
        ["tw:w-full", MAX_WIDTHS[@columns], centering].compact.join(" ")
      end

      def centering
        "tw:mx-auto" if @alignment == :center
      end
    end
  end
end
