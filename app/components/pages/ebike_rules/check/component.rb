# frozen_string_literal: true

module Pages
  module EbikeRules
    module Check
      # The frame a check loads into, which is all a frame request renders
      class Component < ApplicationComponent
        FRAME_ID = "ebike-rules-check"

        def initialize(lookup:, page_title:)
          @lookup = lookup
          @page_title = page_title
        end

        def call
          helpers.turbo_frame_tag(FRAME_ID, class: "tw:block") do
            # A frame response's layout has no title, and the state's is in this one
            safe_join([tag.span(hidden: true, data: {page_title: @page_title}),
              (render(Pages::EbikeRules::Results::Component.new(lookup: @lookup)) if @lookup.result?)].compact)
          end
        end
      end
    end
  end
end
