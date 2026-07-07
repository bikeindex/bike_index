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

      # The seeded superadmin, signed in via the existing magic link flow
      def superadmin
        return @superadmin if defined?(@superadmin)

        @superadmin = User.admins.first
      end

      # Refreshing the token persists it, so force the writing role: the banner
      # renders on pages (e.g. bikes#show) served under set_reading_role.
      def superadmin_magic_link_token
        ActiveRecord::Base.connected_to(role: :writing) do
          superadmin.refreshed_magic_link_token
        end
      end
    end
  end
end
