# frozen_string_literal: true

module PageBlock
  module Navbar
    module Wrapper
      # The site-wide header nav: the logo and the primary menu. A reader with a passive
      # organization gets PageBlock::Navbar::OrgSidebar in its place, which this picks.
      # logo_only renders just the logo, for the OAuth authorization prompt.
      class Component < ApplicationComponent
        # Digest of the cached template — the cached_markup_digest spec keeps it current
        MARKUP_DIGEST = "afd1441e2e35"

        def initialize(logo_only: false, current_user: nil, current_user_or_unconfirmed_user: nil,
          passive_organization: nil)
          @logo_only = logo_only
          @current_user = current_user
          @current_user_or_unconfirmed_user = current_user_or_unconfirmed_user
          @passive_organization = passive_organization
        end

        # The layout asks, since the sidebar is a column the page is laid out around
        # rather than a bar above it
        def org_sidebar?
          org_sidebar.render?
        end

        private

        def org_sidebar
          @org_sidebar ||= PageBlock::Navbar::OrgSidebar::Component.new(organization: @passive_organization,
            current_user: @current_user, current_user_or_unconfirmed_user: @current_user_or_unconfirmed_user)
        end

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
