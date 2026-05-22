# frozen_string_literal: true

module ReviewAppBanner
  # Yellow banner shown across the top of every page on review-app deploys, so
  # there's no chance of confusing a review environment with production.
  # Self-gated via `render?`; defaults read from `ENV["REVIEW_APP"]` and
  # `ENV["REVIEW_APP_PR_NUMBER"]` so the layout just calls `render(...)`.
  class Component < ApplicationComponent
    def initialize(
      present: ENV["REVIEW_APP"].present?,
      pr_number: ENV["REVIEW_APP_PR_NUMBER"].presence
    )
      @present = present
      @pr_number = pr_number
    end

    def render?
      @present
    end

    private

    attr_reader :pr_number

    def pr_url
      "https://github.com/bikeindex/bike_index/pull/#{pr_number}"
    end
  end
end
