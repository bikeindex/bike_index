# frozen_string_literal: true

module PageBlock
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
      ROW_CURRENT = "tw:bg-blue-50 tw:text-blue-600 tw:dark:bg-gray-700"
      ROW_RESTING = "tw:text-gray-900 tw:dark:text-gray-300"

      # A row inside a group, indented past its parent's icon
      CHILD = "tw:mx-2 tw:block tw:rounded-[10px] tw:py-2 tw:pr-3 tw:pl-11 tw:text-[13.5px] " \
        "tw:font-bold tw:whitespace-nowrap tw:max-[760px]:py-3.5"
      CHILD_RESTING = "tw:text-purple-500 tw:dark:text-purple-300"

      # The tracked-out gray caption above the org's name -- POWERED BY and ADMIN PANEL
      ADMIN_PANEL = "tw:text-[10.5px] tw:font-bold tw:tracking-[0.14em] tw:text-gray-400"

      # One bar of the hamburgler, which folds into an X while the menu is open
      BAR = "tw:h-0.5 tw:w-5 tw:rounded-sm tw:bg-gray-900 tw:transition-all " \
        "tw:duration-200 tw:dark:bg-gray-300"

      def initialize(organization:, current_user:, current_user_or_unconfirmed_user: nil,
        controller_namespace: nil, controller_name: nil, action_name: nil)
        @organization = organization
        @current_user = current_user
        @current_user_or_unconfirmed_user = current_user_or_unconfirmed_user || current_user
        @controller_namespace = controller_namespace
        @controller_name = controller_name
        @action_name = action_name
      end

      def render?
        @organization.present? && @current_user.present?
      end

      private

      def items
        @items ||= OrganizedServices::SidebarMenu.for(organization: @organization, current_user: @current_user)
      end

      def account_items
        [{label: translation(".your_registrations"), path: my_account_path},
          {label: translation(".register_a_new_bike"), path: choose_registration_path},
          {label: translation(".user_settings", user_email: @current_user_or_unconfirmed_user.email),
           path: edit_my_account_path},
          {type: :divider},
          {label: translation(".logout"), path: goodbye_path, danger: true}]
      end

      # The group holding the current page opens on load; with none of them holding it
      # the first one does, the way the design shows it
      def open_group?(group)
        group == (active_group || groups.first)
      end

      def row_class(active)
        [ROW, ROW_HOVER, "tw:no-underline", active ? ROW_CURRENT : ROW_RESTING].join(" ")
      end

      def child_class(active)
        [CHILD, "tw:no-underline tw:hover:text-blue-600", active ? ROW_CURRENT : CHILD_RESTING].join(" ")
      end

      # Replaces UI::Button's classes entirely -- this trigger is a sidebar row, not a button.
      # The chevron is the dropdown's own, so collapsing hides it by class rather than by slot
      def account_button_class
        "tw:flex tw:w-full tw:items-center tw:gap-2.5 tw:rounded-[11px] tw:px-2.5 tw:py-2 " \
          "tw:group-data-[collapsed=true]/sidebar:justify-center " \
          "tw:group-data-[collapsed=true]/sidebar:[&_.twdropdown-chevron]:hidden " \
          "tw:hover:bg-gray-100 tw:aria-expanded:bg-gray-100 tw:dark:hover:bg-gray-700"
      end

      def groups
        @groups ||= items.select { |item| item[:type] == :group }
      end

      def active_group
        return @active_group if defined?(@active_group)

        @active_group = groups.find { |group|
          group[:children].any? { |child| child[:type] == :link && active_link?(child) }
        }
      end

      # Memoized because the template asks again for every row the scan above resolved
      def active_link?(item)
        cache = (@active_links ||= {})
        key = [item[:path], item[:active]]
        cache.fetch(key) { cache[key] = resolve_active(item) }
      end

      # UI::ActiveLink leaves this to the browser, which the sidebar can't: the group
      # holding the current page is the one that starts open, and that has to be decided
      # before the rows render
      def resolve_active(item)
        case item[:active]
        when :auto then helpers.current_page_active?(item[:path])
        when :match_controller then helpers.current_page_active?(item[:path], true)
        when :on_registrations_index then organized_controller?("registrations") && @action_name == "index"
        # Both add-a-bike rows are organized/bikes#new, told apart by the query param
        when :on_bikes_new then request.fullpath == item[:path]
        when :on_registration_sequences
          organized_controller?("registration_sequences", "registration_sequence_pages")
        end
      end

      def organized_controller?(*controller_names)
        @controller_namespace == "organized" && controller_names.include?(@controller_name)
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
