# frozen_string_literal: true

module ReviewAppBanner
  class ComponentPreview < ApplicationComponentPreview
    def without_pr_link
      render(ReviewAppBanner::Component.new)
    end

    def with_pr_link
      render(ReviewAppBanner::Component.new(pr_number: 1234))
    end
  end
end
