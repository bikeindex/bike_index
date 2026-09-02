# frozen_string_literal: true

module SharedBlocks
  module Navbar
    module Wrapper
      # The site-wide header nav: the logo and the primary menu. A reader with a passive
      # organization gets SharedBlocks::Navbar::OrgSidebar in its place, which this picks.
      # logo_only renders just the logo, for the OAuth authorization prompt.
      class Component < ApplicationComponent
        # Digest of the cached template — the cached_markup_digest spec keeps it current
        MARKUP_DIGEST = "9d184aaa2192"

        def initialize(logo_only: false, current_user: nil, current_user_or_unconfirmed_user: nil,
          passive_organization: nil, old_register_view: false)
          @logo_only = logo_only
          @current_user = current_user
          @current_user_or_unconfirmed_user = current_user_or_unconfirmed_user
          @passive_organization = passive_organization
          @old_register_view = old_register_view
        end

        # The layout asks, since the sidebar is a column the page is laid out around
        # rather than a bar above it
        def org_sidebar?
          org_sidebar.render?
        end

        private

        def org_sidebar
          @org_sidebar ||= SharedBlocks::Navbar::OrgSidebar::Component.new(organization: @passive_organization,
            current_user: @current_user, old_register_view: @old_register_view)
        end

        # logo_only renders none of the elements the controller drives
        def controller_attributes
          return {} if @logo_only

          {data: {controller: "shared-blocks--navbar",
                  action: "click@window->shared-blocks--navbar#closeDropdownsOutside " \
                    "keydown.esc@window->shared-blocks--navbar#closeOnEscape " \
                    "resize@window->shared-blocks--navbar#reposition"}}
        end

        # The whole nav renders the same on every page a user sees, so the user is the key
        def cache_key
          [MARKUP_DIGEST, @current_user_or_unconfirmed_user]
        end

        def primary_menu
          SharedBlocks::Navbar::PrimaryMenu::Component.new(
            current_user_or_unconfirmed_user: @current_user_or_unconfirmed_user
          )
        end
      end
    end
  end
end
