# frozen_string_literal: true

module UI
  module Container
    # The horizontal bounds of a page's content. A single column of labelled inputs stops
    # being readable before a wide screen runs out - the eye has to cross empty space from
    # the label to its field - so a form that needs more room splits into columns rather
    # than growing. The caller lays its own columns out; this picks the width they share.
    class Component < ApplicationComponent
      MAX_WIDTHS = {1 => "tw:max-w-3xl", 2 => "tw:max-w-7xl"}.freeze
      COLUMNS = MAX_WIDTHS.keys.freeze
      ALIGNMENTS = %i[center left].freeze

      def initialize(columns: 1, full_width: false, alignment: :center)
        raise_if_invalid_value!(:columns, columns, COLUMNS)
        raise_if_invalid_value!(:alignment, alignment, ALIGNMENTS)

        @columns = columns
        @full_width = full_width
        @alignment = alignment
      end

      def call = tag.div(content, class: classes)

      private

      def classes
        ["tw:w-full", gutter, max_width, centering].compact.join(" ")
      end

      # The full-width container is the page's outermost, so it owns the gutter - a capped
      # one nests inside it and would double it
      def gutter
        "tw:px-4" if @full_width
      end

      def max_width
        MAX_WIDTHS[@columns] unless @full_width
      end

      # Nothing to center when it already fills the width
      def centering
        "tw:mx-auto" if @alignment == :center && !@full_width
      end
    end
  end
end
