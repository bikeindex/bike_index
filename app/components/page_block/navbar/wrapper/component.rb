# frozen_string_literal: true

module PageBlock
  module Navbar
    module Wrapper
      # The site-wide header nav: the logo and the primary menu. Readers with a passive
      # organization get PageBlock::OrgSidebar in its place, so it never has to carry one.
      # logo_only renders just the logo, for the OAuth authorization prompt.
      class Component < ApplicationComponent
        # Digest of the cached template — the cached_markup_digest spec keeps it current
        MARKUP_DIGEST = "da694536d447"

        def initialize(logo_only: false, page_id: nil, current_user: nil, current_user_or_unconfirmed_user: nil,
          passive_organization: nil)
          # Everything below keys the fragment cache, so a caller that forgets one would
          # otherwise share a single render across every page
          raise ArgumentError, "page_id is required unless logo_only" if page_id.blank? && !logo_only

          @logo_only = logo_only
          @page_id = page_id
          @current_user = current_user
          @current_user_or_unconfirmed_user = current_user_or_unconfirmed_user
          @passive_organization = passive_organization
        end

        private

        # logo_only renders none of the elements the controller drives
        def controller_attributes
          return {} if @logo_only

          {data: {controller: "page-block--navbar",
                  action: "click@window->page-block--navbar#closeDropdownsOutside " \
                    "keydown.esc@window->page-block--navbar#closeOnEscape " \
                    "resize@window->page-block--navbar#reposition"}}
        end

        def cache_key
          [MARKUP_DIGEST, @page_id, @current_user_or_unconfirmed_user, @passive_organization]
        end

        def primary_menu
          PageBlock::Navbar::PrimaryMenu::Component.new(current_user: @current_user,
            current_user_or_unconfirmed_user: @current_user_or_unconfirmed_user)
        end
      end
    end
  end
end
