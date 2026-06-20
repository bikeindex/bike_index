# frozen_string_literal: true

module PageBlock
  module ReviewAppBanner
    class ComponentPreview < ApplicationComponentPreview
      def with_pr_link
        render(PageBlock::ReviewAppBanner::Component.new(review_app: "1", pr_number: 3664,
          pr_title: "Add Promoted section to marketplace index"))
      end

      # No title available — link falls back to "PR #<number>".
      def without_pr_title
        render(PageBlock::ReviewAppBanner::Component.new(review_app: "1", pr_number: 3664))
      end
    end
  end
end
