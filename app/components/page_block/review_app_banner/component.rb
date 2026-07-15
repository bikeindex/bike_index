# frozen_string_literal: true

module PageBlock
  module ReviewAppBanner
    # Banner shown across the top of every page on review-app deploys, so
    # there's no chance of confusing a review environment with production.
    # Callers pass `ENV["REVIEW_APP"]`, `ENV["REVIEW_APP_PR_NUMBER"]`, and
    # `ENV["REVIEW_APP_PR_TITLE"]`; the component renders only when `review_app`
    # is present.
    class Component < ApplicationComponent
      def initialize(review_app:, pr_number: nil, pr_title: nil, commit: nil, current_user: nil, return_to: nil)
        @review_app = review_app
        @pr_number = pr_number
        @pr_title = pr_title
        @commit = commit
        @current_user = current_user
        @return_to = return_to
      end

      def render?
        @review_app.present?
      end

      private

      # No PR number means the persistent staging deploy, not a per-PR review app
      def banner_label
        @pr_number.present? ? translation(".label") : translation(".label_staging")
      end

      # The PR title when known, falling back to "PR #<number>".
      def pr_link_text
        @pr_title.presence || translation(".pr_link", number: @pr_number)
      end

      def pr_url
        "https://github.com/bikeindex/bike_index/pull/#{@pr_number}"
      end

      def commit_url
        "https://github.com/bikeindex/bike_index/commit/#{@commit}"
      end

      # Green pill styling shared by the commit and email-outbox "?" tooltip triggers
      def pill_button_class
        "tw:inline-flex tw:items-center tw:justify-center tw:h-4 tw:w-4 tw:rounded-full " \
          "tw:bg-[#1e881e] tw:text-white tw:hover:bg-[#166016] tw:text-2xs tw:font-bold tw:cursor-help " \
          "tw:focus:outline-none tw:focus:ring-3 tw:focus:ring-blue-500/40"
      end

      # The seeded superadmin, signed in via the existing magic link flow
      def superadmin
        return @superadmin if defined?(@superadmin)

        @superadmin = User.admins.first
      end

      def signed_in_as_superadmin?
        @current_user.present? && @current_user == superadmin
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
