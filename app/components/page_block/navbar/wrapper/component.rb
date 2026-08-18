# frozen_string_literal: true

module PageBlock
  module Navbar
    module Wrapper
      # The site-wide header nav: the logo and the primary menu. Readers with a passive
      # organization get PageBlock::OrgSidebar in its place, so it never has to carry one.
      # logo_only renders just the logo, for the OAuth authorization prompt.
      class Component < ApplicationComponent
        # Digest of the cached template — the cached_markup_digest spec keeps it current
        MARKUP_DIGEST = "369410c292c4"

        def initialize(logo_only: false, current_user: nil, current_user_or_unconfirmed_user: nil)
          @logo_only = logo_only
          @current_user = current_user
          @current_user_or_unconfirmed_user = current_user_or_unconfirmed_user
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

        # The whole nav renders the same on every page a user sees, so the user is the key
        def cache_key
          [MARKUP_DIGEST, @current_user_or_unconfirmed_user]
        end

        def primary_menu
          PageBlock::Navbar::PrimaryMenu::Component.new(current_user: @current_user,
            current_user_or_unconfirmed_user: @current_user_or_unconfirmed_user)
        end
      end
    end
  end
end
