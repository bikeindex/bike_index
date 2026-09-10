# frozen_string_literal: true

module Pages
  module Register
    module ReviewSummary
      # What the review screen opens with: everything acknowledged, each green-checked. The
      # flow links every row back to its page; the org's preview has nowhere to send them, so
      # it passes no path - and its subtitle drops the invitation to tap one.
      class Component < ApplicationComponent
        # page_path: ->(index) { the path back to page `index` }
        def initialize(pages:, page_path: nil)
          @pages = pages
          @page_path = page_path
        end

        private

        def subtitle
          @page_path.present? ? translation(".a_quick_review_tap") : translation(".a_quick_review")
        end
      end
    end
  end
end
