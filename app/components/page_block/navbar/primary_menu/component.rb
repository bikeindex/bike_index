# frozen_string_literal: true

module PageBlock
  module Navbar
    module PrimaryMenu
      # The navbar's main menu, rendered from a manifest of items rather than repeated markup
      class Component < ApplicationComponent
        def initialize(current_user:, current_user_or_unconfirmed_user:, controller_namespace:,
          controller_name:, action_name:)
          @current_user = current_user
          @current_user_or_unconfirmed_user = current_user_or_unconfirmed_user
          @controller_namespace = controller_namespace
          @controller_name = controller_name
          @action_name = action_name
        end

        private

        def menu_items
          [search_item("d-lg-none"),
            marketplace_item("d-lg-none"),
            {type: :divider, item_class: "d-lg-none"},
            *account_items,
            {label: translation(".help"), path: help_path},
            # Because of caching, this needs to be set to be active with JS (welcome/index.coffee)
            {label: translation(".stolen_bike"), path: get_your_stolen_bike_back_path, active: false,
             html_options: {id: "getStolenBackLink"}},
            {label: translation(".donate"), path: why_donate_path},
            {label: translation(".blog"), path: news_index_path, active: :match_controller},
            marketplace_item("d-lg-block"),
            search_item("d-none d-lg-block")]
        end

        def search_item(item_class)
          {label: translation(".search"), path: helpers.default_bike_search_path,
           active: search_active?("registrations"), item_class:}
        end

        def marketplace_item(item_class)
          {label: translation(".marketplace"), path: search_marketplace_path,
           active: search_active?("marketplace"), item_class:}
        end

        def account_items
          return [{type: :settings}, {type: :divider}] if @current_user_or_unconfirmed_user.present?

          [{label: translation(".sign_up"), path: new_user_url, link_class: "signup-link"},
            {label: translation(".log_in"), path: new_session_url}]
        end

        def settings_items
          [*organization_items,
            {label: translation(".your_registrations"), path: my_account_path},
            marketplace_messages_item,
            {label: translation(".register_a_new_bike"), path: choose_registration_path},
            {label: translation(".user_settings", user_email: @current_user_or_unconfirmed_user.email),
             path: edit_my_account_path,
             html_options: {id: "navUserSettingLink", data: {email: @current_user_or_unconfirmed_user.email}}},
            {type: :divider},
            {label: translation(".logout"), path: goodbye_path, active: false}].compact
        end

        def organization_items
          organizations = @current_user_or_unconfirmed_user.organization_roles.includes(:organization)
            .filter_map(&:organization)
          return [] if organizations.none?

          organizations.map { |organization|
            {label: translation(".view_org", org_name: organization.name),
             path: organization_root_path(organization_id: organization.to_param), active: false}
          } + [{type: :divider}]
        end

        # .any_for_user? caches
        def marketplace_messages_item
          return unless MarketplaceMessage.any_for_user?(@current_user)

          {label: translation(".marketplace_messages"), path: my_account_messages_path}
        end

        # nil computes active from the path, :match_controller from the controller alone, false
        # pins it inactive -- swapping nil for false fails silently
        def menu_link(item)
          options = {class: link_class(item), **item.fetch(:html_options, {})}
          case item[:active]
          when nil, :match_controller
            helpers.active_link(item[:label], item[:path], match_controller: item[:active] == :match_controller, **options)
          else
            link_to(item[:label], item[:path], **options)
          end
        end

        def link_class(item)
          ["nav-link", item[:link_class], ("active" if item[:active] == true)].compact.join(" ")
        end

        def search_active?(controller_name)
          @controller_namespace == "search" && @controller_name == controller_name && @action_name == "index"
        end
      end
    end
  end
end
