# frozen_string_literal: true

module UI
  module DefinitionList
    module Container
      class Component < ApplicationComponent
        # term: placement of each row's term (dt) relative to its definition (dd).
        # The non-default terms style the child Row divs/dt/dd via descendant
        # selectors (which out-specify the Row's own utility classes), so Rows
        # need no term awareness.
        #
        # :left_align  — term left, definition right-aligned (supports multi_columns)
        # :right_align — term right-aligned in a fixed column, definition beside it
        # :below       — definition below the term, three columns desktop / two mobile
        TERMS = %i[left_align right_align below].freeze

        # Summary panel (single column): keeps the Row's label-left / value-right
        # layout (justify-between), just resizing to consumer_desktop.html — label
        # 13px, value 13.5px semibold
        PANEL_CLASSES = "tw:flex tw:flex-col tw:gap-2.5 tw:break-words " \
          "tw:[&>div]:pt-0 " \
          "tw:[&>div>dt]:text-[13px] " \
          "tw:[&>div>dd]:text-[13.5px] tw:[&>div>dd]:font-semibold"

        # Spec-sheet lists (multi column): right-aligned label column beside
        # normal-weight values, two columns on desktop
        SPECS_CLASSES = "tw:grid tw:grid-cols-1 tw:gap-x-[22px] tw:gap-y-[13px] tw:break-words tw:sm:grid-cols-2 " \
          "tw:[&>div]:pt-0 tw:[&>div]:gap-x-3 " \
          "tw:[&>div>dt]:w-28 tw:[&>div>dt]:flex-none tw:[&>div>dt]:text-right tw:[&>div>dt]:text-[13px] " \
          "tw:[&>div>dd]:flex-1 tw:[&>div>dd]:text-left tw:[&>div>dd]:text-[13.5px]"

        BELOW_CLASSES = "tw:grid tw:grid-cols-2 tw:gap-x-5 tw:gap-y-[18px] tw:break-words tw:lg:grid-cols-3 " \
          "tw:[&>div]:block tw:[&>div]:pt-0 " \
          "tw:[&>div>dt]:mb-[3px] tw:[&>div>dt]:text-[11.5px] " \
          "tw:[&>div>dd]:text-left tw:[&>div>dd]:text-[14px] tw:[&>div>dd]:font-medium"

        def initialize(term: :left_align, multi_columns: false)
          raise ArgumentError, "term must be one of #{TERMS.inspect}, got #{term.inspect}" unless TERMS.include?(term)

          @term = term
          @multi_columns = multi_columns
        end

        private

        def dl_classes
          return BELOW_CLASSES if @term == :below

          # A right_align list is a spec sheet when multi-column, otherwise a
          # single-column summary panel (label left, value right)
          @multi_columns ? SPECS_CLASSES : PANEL_CLASSES
        end
      end
    end
  end
end
