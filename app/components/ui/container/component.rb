# frozen_string_literal: true

module UI
  module Container
    # The horizontal bounds of a page's content: how wide it may get, and where the slack
    # goes when it doesn't. A single column of labelled inputs stops being readable well
    # before a wide screen runs out - the eye has to cross empty space from the label to
    # its field - so a form that needs more room splits into columns rather than growing.
    # The caller lays its own columns out; this only picks the width they share.
    #
    # The widths are the ones the app already uses: 3xl is what the admin
    # registration-sequence screens center on, 7xl what the search results do.
    #
    # full_width: the whole viewport, for a page that isn't reading-width - an index
    # table, or the admin layout the other containers sit inside.
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

      # px-4 rather than the 15px .container-fluid used - the app's own gutter, and the
      # half-pixel difference isn't worth a magic number
      def classes
        ["tw:w-full tw:px-4", max_width, centering].compact.join(" ")
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
