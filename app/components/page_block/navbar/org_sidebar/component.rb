# frozen_string_literal: true

module PageBlock
  module Navbar
    module OrgSidebar
      # The organization admin sidebar. It stands in for the whole navbar on every page a
      # member with a passive organization sees, so it carries their account links too.
      class Component < ApplicationComponent
        COLLAPSE_BREAKPOINT = 1100
        MOBILE_BREAKPOINT = 760

        # A top-level row -- the group toggles and the leaf links share it, so they stay
        # the same height as each other
        ROW = "tw:mx-2 tw:flex tw:items-center tw:gap-[11px] tw:rounded-[11px] tw:px-3 tw:py-[9px] " \
          "tw:text-sm tw:font-bold tw:group-data-[collapsed=true]/sidebar:justify-center tw:max-[760px]:py-3.5"
        ROW_HOVER = "tw:hover:bg-gray-100 tw:dark:hover:bg-gray-700"
        # A link goes current off the aria-current the is-active variant already reads; a group
        # toggle off the data-active page-block--org-sidebar puts on the one holding that link
        ROW_CURRENT = "tw:is-active:bg-blue-50 tw:is-active:text-blue-600 tw:is-active:dark:bg-gray-700"
        ROW_RESTING = "tw:text-gray-900 tw:dark:text-gray-300"

        # A row inside a group, indented past its parent's icon
        CHILD = "tw:mx-2 tw:block tw:rounded-[10px] tw:py-2 tw:pr-3 tw:pl-11 tw:text-[13.5px] " \
          "tw:font-bold tw:whitespace-nowrap tw:max-[760px]:py-3.5"
        CHILD_RESTING = "tw:text-purple-500 tw:dark:text-purple-300"

        # The tracked-out gray ADMIN PANEL caption, beside the logo and above the org's name
        ADMIN_PANEL = "tw:text-[10.5px] tw:font-bold tw:tracking-[0.14em] tw:text-gray-400"

        # One bar of the hamburgler, which folds into an X while the menu is open
        BAR = "tw:h-0.5 tw:w-5 tw:rounded-sm tw:bg-gray-900 tw:transition-all " \
          "tw:duration-200 tw:dark:bg-gray-300"

        def initialize(organization:, current_user:, current_user_or_unconfirmed_user: nil)
          @organization = organization
          @current_user = current_user
          @current_user_or_unconfirmed_user = current_user_or_unconfirmed_user || current_user
        end

        def render?
          @organization.present? && @current_user.present?
        end

        private

        def items
          @items ||= OrganizedServices::UserMenuItems.for(organization: @organization, current_user: @current_user)
        end

        # PageBlock::Navbar::SettingsMenu's rows, in its order — the sidebar stands in for the
        # whole navbar, so this is the only place a reader with an organization reaches them
        def account_items
          [*UserServices::AccountMenuItems.organization_switcher(@current_user_or_unconfirmed_user),
            {label: translation(".your_registrations"), path: my_account_path},
            UserServices::AccountMenuItems.marketplace_messages(@current_user),
            {label: translation(".register_a_new_bike"), path: choose_registration_path},
            {label: translation(".user_settings", user_email: @current_user_or_unconfirmed_user.email),
             path: edit_my_account_path},
            {type: :divider},
            {label: translation(".logout"), path: goodbye_path, danger: true}].compact
        end

        def first_group
          @first_group ||= items.find { |item| item[:type] == :group }
        end

        # text: is the caller's, since a top-level row's label sits inside a block with its icon
        def active_link(item, row_class:, text: nil)
          UI::ActiveLink::Component.from_item(item, html_class: row_class, text:)
        end

        def row_class
          [ROW, ROW_HOVER, "tw:no-underline", ROW_RESTING, ROW_CURRENT].join(" ")
        end

        def child_class
          [CHILD, "tw:no-underline tw:hover:text-blue-600", CHILD_RESTING, ROW_CURRENT].join(" ")
        end

        # Replaces UI::Button's classes entirely -- this trigger is a sidebar row, not a button.
        # The chevron is the dropdown's own, so collapsing hides it by class rather than by slot
        def account_button_class
          "tw:flex tw:w-full tw:items-center tw:gap-2.5 tw:rounded-[11px] tw:px-2.5 tw:py-2 " \
            "tw:group-data-[collapsed=true]/sidebar:justify-center " \
            "tw:group-data-[collapsed=true]/sidebar:[&_.twdropdown-chevron]:hidden " \
            "tw:hover:bg-gray-100 tw:aria-expanded:bg-gray-100 tw:dark:hover:bg-gray-700"
        end

        def avatar_url
          return @avatar_url if defined?(@avatar_url)

          @avatar_url = OrganizationDisplayer.avatar?(@organization) ? @organization.avatar.url(:medium) : nil
        end

        def icon(name, html_class:)
          helpers.inline_svg_tag("icons/#{name}.svg", class: html_class)
        end
      end
    end
  end
end
