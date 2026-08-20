# frozen_string_literal: true

module PageBlock
  module Navbar
    module AccountMenu
      # UserServices::MenuItemsAccount's rows as the org sidebar's account block: a UI::Dropdown
      # whose trigger is the caller's content. It opens upward, off the foot of the column, so
      # the rows run the other way from PageBlock::Navbar::UserSettingsMenu's.
      class Component < ApplicationComponent
        LOGOUT = "tw:text-red-700! tw:hover:bg-red-50! tw:hover:text-red-600!"

        def initialize(current_user:, current_user_or_unconfirmed_user:, name:,
          current_organization: nil, button_class: nil)
          @current_user = current_user
          @current_user_or_unconfirmed_user = current_user_or_unconfirmed_user
          @name = name
          @current_organization = current_organization
          @button_class = button_class
        end

        private

        def items
          UserServices::MenuItemsAccount.for(current_user: @current_user,
            current_user_or_unconfirmed_user: @current_user_or_unconfirmed_user,
            current_organization: @current_organization, opens: :up)
        end

        # .twdropdown (bike_index_components.css) styles the entries, so they need nothing
        def entry(item)
          UI::ActiveLink::Component.from_item(item, html_class: (LOGOUT if item[:danger]))
        end
      end
    end
  end
end
