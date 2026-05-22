# frozen_string_literal: true

module ReviewAppBanner
  class ComponentPreview < ApplicationComponentPreview
    def without_pr_link
      render(ReviewAppBanner::Component.new(review_app: "1"))
    end

    def with_pr_link
      render(ReviewAppBanner::Component.new(review_app: "1", pr_number: 1234))
    end
  end
end
