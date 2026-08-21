# frozen_string_literal: true

module PageBlock
  module Navbar
    module UserSettingsMenu
      # UserServices::MenuItemsAccount's rows as the navbar's gear and its own <ul>, which
      # primary_header_nav.scss styles and page-block--navbar opens -- and which below the
      # navbar breakpoint sits inline in the hamburgler menu rather than behind a trigger.
      # PageBlock::Navbar::AccountMenu is the same rows in the org sidebar.
      class Component < ApplicationComponent
        # red-700 against the navbar's near-black panel is unreadable, so logout takes a tint
        # that carries on dark
        LOGOUT = "tw:text-red-400! tw:hover:text-red-300!"

        def initialize(current_user_or_unconfirmed_user:)
          @current_user_or_unconfirmed_user = current_user_or_unconfirmed_user
        end

        private

        def items
          UserServices::MenuItemsAccount.for(
            current_user_or_unconfirmed_user: @current_user_or_unconfirmed_user
          )
        end

        # .nav-link is the navbar's own, which the submenu's rows take with the rest of its links
        def entry(item)
          UI::ActiveLink::Component.from_item(item,
            html_class: ["nav-link", (LOGOUT if item[:danger])].compact.join(" "))
        end
      end
    end
  end
end
