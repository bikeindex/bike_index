# frozen_string_literal: true

module PageBlock
  module ReviewAppBanner
    # Banner shown across the top of every page on review-app deploys, so
    # there's no chance of confusing a review environment with production.
    # Callers pass `ENV["REVIEW_APP"]` and `ENV["REVIEW_APP_PR_NUMBER"]`; the
    # component renders only when `review_app` is present.
    class Component < ApplicationComponent
      def initialize(review_app:, pr_number: nil)
        @review_app = review_app
        @pr_number = pr_number
      end

      def render?
        @review_app.present?
      end

      private

      def pr_url
        "https://github.com/bikeindex/bike_index/pull/#{@pr_number}"
      end
    end
  end
end
