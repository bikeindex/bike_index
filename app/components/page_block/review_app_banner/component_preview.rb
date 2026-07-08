# frozen_string_literal: true

module PageBlock
  module ReviewAppBanner
    class ComponentPreview < ApplicationComponentPreview
      def with_pr_link
        render(PageBlock::ReviewAppBanner::Component.new(review_app: "1", pr_number: 3664,
          pr_title: "Add Promoted section to marketplace index"))
      end

      # No title available — link falls back to "PR #<number>".
      def without_pr_title
        render(PageBlock::ReviewAppBanner::Component.new(review_app: "1", pr_number: 3664))
      end

      # Superadmin sign-in button, carrying the current page as return_to.
      def superadmin_sign_in
        render(PageBlock::ReviewAppBanner::Component.new(review_app: "1", pr_number: 3664,
          return_to: "/bikes/12"))
      end

      # Already signed in as the superadmin — de-emphasized italic label.
      def superadmin_signed_in
        render(PageBlock::ReviewAppBanner::Component.new(review_app: "1", pr_number: 3664,
          current_user: User.admins.first))
      end
    end
  end
end
