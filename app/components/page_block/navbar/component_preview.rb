# frozen_string_literal: true

module PageBlock
  module Navbar
    class ComponentPreview < ApplicationComponentPreview
      # @!group Navbar

      # page_id keys the fragment cache — a real page's id would serve this preview's
      # render to that page when dev caching is on
      PAGE = {page_id: "lookbook_preview", controller_namespace: nil,
              controller_name: "welcome", action_name: "index"}.freeze

      # @display legacy_stylesheet true
      def default
        render(PageBlock::Navbar::Component.new(**PAGE, current_user: nil,
          current_user_or_unconfirmed_user: nil))
      end

      # @display legacy_stylesheet true
      def signed_in
        render(PageBlock::Navbar::Component.new(**PAGE, current_user: lookbook_user,
          current_user_or_unconfirmed_user: lookbook_user))
      end

      # @display legacy_stylesheet true
      def with_organization
        render(PageBlock::Navbar::Component.new(**PAGE, current_user: lookbook_user,
          current_user_or_unconfirmed_user: lookbook_user, passive_organization: lookbook_organization))
      end

      # @display legacy_stylesheet true
      def logo_only
        render(PageBlock::Navbar::Component.logo_only)
      end
      # @endgroup
    end
  end
end
