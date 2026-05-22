# frozen_string_literal: true

module ReviewAppBanner
  # Yellow banner shown across the top of every page on review-app deploys, so
  # there's no chance of confusing a review environment with production. The
  # layout decides whether to render it (gated on `ENV["REVIEW_APP"]`); this
  # component just takes a PR number and renders the strip.
  class Component < ApplicationComponent
    def initialize(pr_number: nil)
      @pr_number = pr_number
    end

    private

    attr_reader :pr_number

    def pr_url
      "https://github.com/bikeindex/bike_index/pull/#{pr_number}"
    end
  end
end
