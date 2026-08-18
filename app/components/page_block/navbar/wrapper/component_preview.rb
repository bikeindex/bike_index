# frozen_string_literal: true

module PageBlock
  module Navbar
    module Wrapper
      class ComponentPreview < ApplicationComponentPreview
        # @!group Navbar

        # page_id keys the fragment cache — a real page's id would serve this preview's
        # render to that page when dev caching is on
        PAGE = {page_id: "lookbook_preview"}.freeze

        # @display legacy_stylesheet true
        def default
          render(PageBlock::Navbar::Wrapper::Component.new(**PAGE))
        end

        # @display legacy_stylesheet true
        def signed_in
          render(PageBlock::Navbar::Wrapper::Component.new(**PAGE, current_user: lookbook_user,
            current_user_or_unconfirmed_user: lookbook_user))
        end

        # @display legacy_stylesheet true
        def logo_only
          render(PageBlock::Navbar::Wrapper::Component.new(logo_only: true))
        end
        # @endgroup
      end
    end
  end
end
