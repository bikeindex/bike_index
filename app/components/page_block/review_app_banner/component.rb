# frozen_string_literal: true

module PageBlock
  module ReviewAppBanner
    # Banner shown across the top of every page on review-app and local dev
    # deploys, so there's no chance of confusing them with production. Deploys
    # build it with `.from_env`; the component renders only when `review_app` is
    # present, so previews can pass one explicitly.
    class Component < ApplicationComponent
      # `review_app` is nil — so nothing renders — in production and when
      # NO_REVIEW_TOPBAR=true. The Lookbook navbar is scoped through here too
      # (config/initializers/lookbook.rb)
      def self.from_env(current_user: nil, return_to: nil)
        review_app = ENV["REVIEW_APP"] || (Rails.env.development? && "development")
        review_app = nil if Rails.env.production? || ENV["NO_REVIEW_TOPBAR"] == "true"

        new(review_app:, pr_number: ENV["REVIEW_APP_PR_NUMBER"], pr_title: ENV["REVIEW_APP_PR_TITLE"],
          commit: ENV["REVIEW_APP_COMMIT"], current_user:, return_to:)
      end

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

      # Only a PR is worth the navbar space; dev and sandbox deploys get nothing.
      def lookbook_navbar_title
        pr_link_text if render? && @pr_number.present?
      end

      private

      def development?
        @review_app == "development"
      end

      # "development" is the local dev server; no PR number is the persistent
      # sandbox deploy; otherwise a per-PR review app
      def banner_label
        return translation(".label_development") if development?

        @pr_number.present? ? translation(".label") : translation(".label_sandbox")
      end

      # Purple on the local dev server (matching the dev favicon), green on
      # review apps. Full literal classes so tailwind's scanner emits both.
      def banner_accent_class
        development? ? "tw:border-[#881e88] tw:bg-[#ff40ff]" : "tw:border-[#1e881e] tw:bg-[#40ff40]"
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

      # Pill styling shared by the commit and email-outbox "?" tooltip triggers,
      # matching the banner accent (purple in dev, green on review apps)
      def pill_button_class
        pill_color = development? ? "tw:bg-[#881e88] tw:hover:bg-[#601660]" : "tw:bg-[#1e881e] tw:hover:bg-[#166016]"
        "tw:inline-flex tw:items-center tw:justify-center tw:h-4 tw:w-4 tw:rounded-full " \
          "#{pill_color} tw:text-white tw:text-2xs tw:font-bold tw:cursor-help " \
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
