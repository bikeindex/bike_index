# frozen_string_literal: true

module SharedBlocks
  module Navbar
    module PrimaryMenu
      # The navbar's main menu, rendered from a manifest of items rather than repeated markup
      class Component < ApplicationComponent
        # Rows that exist on both sides of the navbar's breakpoint, so each has to hide
        # on the other -- the desktop side takes two classes, mobile-first
        SIDE_CLASSES = {mobile: "d-lg-none", desktop: "d-none d-lg-block"}.freeze

        def initialize(current_user_or_unconfirmed_user:)
          @current_user_or_unconfirmed_user = current_user_or_unconfirmed_user
        end

        private

        def menu_items
          [search_item(:mobile),
            marketplace_item(:mobile),
            {type: :divider, item_class: SIDE_CLASSES.fetch(:mobile)},
            *account_items,
            {label: translation(".help"), path: help_path},
            {label: translation(".stolen_bike"), path: get_your_stolen_bike_back_path},
            {label: translation(".donate"), path: why_donate_path},
            {label: translation(".blog"), path: news_index_path, match_paths: "#{news_index_path}/**"},
            marketplace_item(:desktop),
            search_item(:desktop)]
        end

        # Active anywhere in the registration search — any stolenness, a query, page 2 — which
        # naming no match_params gets: the stolenness this happens to link to isn't compared
        def search_item(side)
          {label: translation(".search"), path: helpers.default_bike_search_path,
           item_class: SIDE_CLASSES.fetch(side)}
        end

        def marketplace_item(side)
          {label: translation(".marketplace"), path: search_marketplace_path,
           item_class: SIDE_CLASSES.fetch(side)}
        end

        def account_items
          return [{type: :settings}, {type: :divider}] if @current_user_or_unconfirmed_user.present?

          [{label: translation(".sign_up"), path: new_user_url, link_class: "signup-link"},
            {label: translation(".log_in"), path: new_session_url}]
        end

        def settings_menu
          SharedBlocks::Navbar::UserSettingsMenu::Component.new(
            current_user_or_unconfirmed_user: @current_user_or_unconfirmed_user
          )
        end

        # item_class dresses the <li>, link_class the anchor inside it
        def nav_link(item)
          UI::ActiveLink::Component.from_item(item,
            html_class: ["nav-link", item[:link_class]].compact.join(" "))
        end
      end
    end
  end
end
