# frozen_string_literal: true

module PageBlock
  module ReviewAppBanner
    class ComponentPreview < ApplicationComponentPreview
      def with_pr_link
        render(PageBlock::ReviewAppBanner::Component.new(review_app: "1", pr_number: 3664))
      end
    end
  end
end
