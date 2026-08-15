# frozen_string_literal: true

module PageBlock
  module Navbar
    class ComponentPreview < ApplicationComponentPreview
      # @!group Navbar

      # @display legacy_stylesheet true
      def default
        render(PageBlock::Navbar::Component.new(current_user: nil, current_user_or_unconfirmed_user: nil,
          passive_organization: nil, page_id: "welcome_index"))
      end

      # @display legacy_stylesheet true
      def signed_in
        render(PageBlock::Navbar::Component.new(current_user: lookbook_user, current_user_or_unconfirmed_user: lookbook_user,
          passive_organization: nil, page_id: "welcome_index"))
      end

      # @display legacy_stylesheet true
      def with_organization
        render(PageBlock::Navbar::Component.new(current_user: lookbook_user, current_user_or_unconfirmed_user: lookbook_user,
          passive_organization: lookbook_organization, page_id: "welcome_index"))
      end

      # @display legacy_stylesheet true
      def logo_only
        render(PageBlock::Navbar::Component.new(logo_only: true))
      end
      # @endgroup
    end
  end
end
