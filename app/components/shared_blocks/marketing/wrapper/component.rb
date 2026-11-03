# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module Wrapper
      # The full-bleed shell of the marketing pages, flush under the navbar and against the footer.
      # Its ink is the headings' color, so a page sets its muted body copy itself.
      # Wrapped where the page renders rather than picked by route in SharedBlocks::MainContent::Wrapper,
      # since FeedbacksController re-renders some of them
      class Component < ApplicationComponent
        # Every marketing section's content width
        CONTAINER_CLASSES = "tw:mx-auto tw:max-w-6xl tw:px-5 tw:lg:px-14"

        def initialize(page:)
          @page = page
        end
      end
    end
  end
end
