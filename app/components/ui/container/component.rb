# frozen_string_literal: true

module UI
  module Container
    # Caps how wide the content inside it gets. A single column of labelled inputs stops
    # being readable before a wide screen runs out - the eye has to cross empty space from
    # the label to its field - so :form is the width one column should stop at, and :wide
    # the width for content that earns more (two columns of fields, a table, an HTML
    # editor). Laying those columns out is the caller's job.
    #
    # The page owns its gutter (.twgutter); this only caps width, so containers nest
    # without doubling padding.
    class Component < ApplicationComponent
      MAX_WIDTHS = {form: "tw:max-w-3xl", wide: "tw:max-w-7xl"}.freeze
      WIDTHS = MAX_WIDTHS.keys.freeze
      ALIGNMENTS = %i[center left].freeze

      def initialize(width: :form, alignment: :center)
        raise_if_invalid_value!(:width, width, WIDTHS)
        raise_if_invalid_value!(:alignment, alignment, ALIGNMENTS)

        @width = width
        @alignment = alignment
      end

      def call = tag.div(content, class: classes)

      private

      def classes
        ["tw:w-full", MAX_WIDTHS[@width], centering].compact.join(" ")
      end

      def centering
        "tw:mx-auto" if @alignment == :center
      end
    end
  end
end
