# frozen_string_literal: true

module PageBlock
  module ReviewAppBanner
    # Banner shown across the top of every page on review-app deploys, so
    # there's no chance of confusing a review environment with production.
    # Callers pass `ENV["REVIEW_APP"]`, `ENV["REVIEW_APP_PR_NUMBER"]`, and
    # `ENV["REVIEW_APP_PR_TITLE"]`; the component renders only when `review_app`
    # is present.
    class Component < ApplicationComponent
      def initialize(review_app:, pr_number: nil, pr_title: nil)
        @review_app = review_app
        @pr_number = pr_number
        @pr_title = pr_title
      end

      def render?
        @review_app.present?
      end

      private

      # The PR title when known, falling back to "PR #<number>".
      def pr_link_text
        @pr_title.presence || translation(".pr_link", number: @pr_number)
      end

      def pr_url
        "https://github.com/bikeindex/bike_index/pull/#{@pr_number}"
      end
    end
  end
end
