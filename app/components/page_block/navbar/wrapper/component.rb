# frozen_string_literal: true

module PageBlock
  module Navbar
    module Wrapper
      # The site-wide header nav: the logo, then the organization menu and the primary menu.
      # logo_only renders just the logo, for the OAuth authorization prompt.
      class Component < ApplicationComponent
        # Digest of the cached template — the cached_markup_digest spec keeps it current
        MARKUP_DIGEST = "a75c37da8ae7"

        def initialize(logo_only: false, current_user: nil, current_user_or_unconfirmed_user: nil,
          passive_organization: nil, controller_namespace: nil, controller_name: nil, action_name: nil)
          @logo_only = logo_only
          @current_user = current_user
          @current_user_or_unconfirmed_user = current_user_or_unconfirmed_user
          @passive_organization = passive_organization
          @controller_namespace = controller_namespace
          @controller_name = controller_name
          @action_name = action_name
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

        # The cached region is the menus below the organization one, which are the same on
        # every page a user sees
        def cache_key
          [MARKUP_DIGEST, @current_user_or_unconfirmed_user]
        end

        def organization_menu
          PageBlock::Navbar::OrganizationMenu::Component.new(organization: @passive_organization,
            current_user: @current_user, controller_namespace: @controller_namespace,
            controller_name: @controller_name, action_name: @action_name)
        end

        def primary_menu
          PageBlock::Navbar::PrimaryMenu::Component.new(current_user: @current_user,
            current_user_or_unconfirmed_user: @current_user_or_unconfirmed_user)
        end
      end
    end
  end
end
