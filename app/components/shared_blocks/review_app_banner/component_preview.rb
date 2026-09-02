# frozen_string_literal: true

module SharedBlocks
  module ReviewAppBanner
    class ComponentPreview < ApplicationComponentPreview
      def with_pr_link
        render(SharedBlocks::ReviewAppBanner::Component.new(review_app: "1", pr_number: 3664,
          pr_title: "Add Promoted section to marketplace index", commit: "a1b2c3d"))
      end

      # Persistent sandbox deploy — no PR number, so the label reads "Sandbox".
      def sandbox
        render(SharedBlocks::ReviewAppBanner::Component.new(review_app: "1", commit: "a1b2c3d"))
      end

      # Local dev server — the label reads "Development".
      def development
        render(SharedBlocks::ReviewAppBanner::Component.new(review_app: "development"))
      end

      # No title available — link falls back to "PR #<number>".
      def without_pr_title
        render(SharedBlocks::ReviewAppBanner::Component.new(review_app: "1", pr_number: 3664))
      end

      # Superadmin sign-in button, carrying the current page as return_to.
      def superadmin_sign_in
        render(SharedBlocks::ReviewAppBanner::Component.new(review_app: "1", pr_number: 3664,
          return_to: "/bikes/12"))
      end

      # Already signed in as the superadmin — de-emphasized italic label.
      def superadmin_signed_in
        render(SharedBlocks::ReviewAppBanner::Component.new(review_app: "1", pr_number: 3664,
          current_user: User.admins.first))
      end
    end
  end
end
