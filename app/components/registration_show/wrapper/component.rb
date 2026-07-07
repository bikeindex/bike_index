# frozen_string_literal: true

module RegistrationShow
  module Wrapper
    # Renders the registration show page as the resolved perspective (:public,
    # :owner, or an Organization admin view) and fragment-caches it. When the
    # viewer is allowed more than one perspective it also renders a switcher
    # that links to the others via ?view_as=.
    class Component < ApplicationComponent
      def initialize(bike:, current_user:, view:, available_views:, mapbox_key: nil)
        @bike = bike
        @current_user = current_user
        @view = view
        @available_views = available_views
        @mapbox_key = mapbox_key
      end

      private

      def inner_component
        if @view.is_a?(Organization)
          OrgAdmin::Component.new(bike: @bike, current_user: @current_user, organization: @view,
            mapbox_key: @mapbox_key, available_views: @available_views)
        else
          Consumer::Component.new(bike: @bike, current_user: @current_user, owner: @view == :owner,
            show_for_sale: @bike.is_for_sale?, mapbox_key: @mapbox_key, available_views: @available_views)
        end
      end

      # Keyed on the viewer too: the admin view has per-user content + CSRF tokens
      def cache_key
        ["registration_show", @current_user&.id, view_param, @bike.cache_key_with_version]
      end

      def view_param
        @view.is_a?(Organization) ? @view.to_param : @view.to_s
      end
    end
  end
end
