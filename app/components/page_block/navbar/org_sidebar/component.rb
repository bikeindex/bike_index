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

        # Set off from the organization's own rows, which the super admin one isn't
        SUPER_ADMIN_ROW = "tw:mt-4"
        # Stands in for an icon so the label lines up with the rows that carry one, and
        # becomes what the row is recognizable by once there's no label to read
        SUPER_ADMIN_ICON = "tw:flex tw:h-[17px] tw:w-[17px] tw:flex-none tw:items-center " \
          "tw:justify-center tw:rounded-full tw:text-[8px] " \
          "tw:group-data-[collapsed=true]/sidebar:border tw:group-data-[collapsed=true]/sidebar:border-current"

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
          @items ||= UserServices::MenuItemsOrg.for(organization: @organization, current_user: @current_user) +
            super_admin_items
        end

        # Outside MenuItemsOrg's cache, which is keyed on the user record -- granting a
        # SuperuserAbility doesn't touch it, and api/v3/me has no use for an admin link
        def super_admin_items
          return [] unless @current_user.superuser?

          [{type: :link, icon: nil, match: :path, matching_controllers: [], super_admin: true,
            label: translation(".in_super_admin", org_name: @organization.short_name),
            path: admin_organization_path(@organization.to_param)}]
        end

        def account_menu
          PageBlock::Navbar::AccountMenu::Component.new(current_user: @current_user,
            current_user_or_unconfirmed_user: @current_user_or_unconfirmed_user,
            current_organization: @organization,
            name: @current_user_or_unconfirmed_user.email, button_class: account_button_class)
        end

        def first_group
          @first_group ||= items.find { |item| item[:type] == :group }
        end

        # text: is the caller's, since a top-level row's label sits inside a block with its icon
        def active_link(item, row_class:, text: nil)
          UI::ActiveLink::Component.new(path: item[:path], text:, match: item[:match],
            matching_controllers: item[:matching_controllers], class: row_class)
        end

        def row_class
          [ROW, ROW_HOVER, "tw:no-underline", ROW_RESTING, ROW_CURRENT].join(" ")
        end

        def link_row_class(item)
          [row_class, (SUPER_ADMIN_ROW if item[:super_admin])].compact.join(" ")
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

          @avatar_url = OrgServices::Displayer.avatar?(@organization) ? @organization.avatar.url(:medium) : nil
        end

        def icon(name, html_class:)
          helpers.inline_svg_tag("icons/#{name}.svg", class: html_class)
        end
      end
    end
  end
end
