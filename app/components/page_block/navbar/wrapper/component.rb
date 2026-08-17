# frozen_string_literal: true

module PageBlock
  module Navbar
    module Wrapper
      # The site-wide header nav: the logo, then the organization menu and the primary menu.
      # logo_only renders just the logo, for the OAuth authorization prompt.
      class Component < ApplicationComponent
        # Digest of the cached template — the cached_markup_digest spec keeps it current
        MARKUP_DIGEST = "201aacc5834b"

        def initialize(logo_only: false, page_id: nil, current_user: nil, current_user_or_unconfirmed_user: nil,
          passive_organization: nil, controller_namespace: nil, controller_name: nil, action_name: nil,
          unregistered_parking_notification: nil)
          # Everything below keys the fragment cache, so a caller that forgets one would
          # otherwise share a single render across every page
          raise ArgumentError, "page_id is required unless logo_only" if page_id.blank? && !logo_only

          @logo_only = logo_only
          @page_id = page_id
          @current_user = current_user
          @current_user_or_unconfirmed_user = current_user_or_unconfirmed_user
          @passive_organization = passive_organization
          @controller_namespace = controller_namespace
          @controller_name = controller_name
          @action_name = action_name
          @unregistered_parking_notification = unregistered_parking_notification
        end

        private

        def cache_key
          [MARKUP_DIGEST, @page_id, @current_user_or_unconfirmed_user, @passive_organization,
            @unregistered_parking_notification]
        end

        def organization_menu
          PageBlock::Navbar::OrganizationMenu::Component.new(organization: @passive_organization,
            current_user: @current_user, controller_namespace: @controller_namespace,
            controller_name: @controller_name, action_name: @action_name,
            unregistered_parking_notification: @unregistered_parking_notification)
        end

        def primary_menu
          PageBlock::Navbar::PrimaryMenu::Component.new(current_user: @current_user,
            current_user_or_unconfirmed_user: @current_user_or_unconfirmed_user)
        end
      end
    end
  end
end
