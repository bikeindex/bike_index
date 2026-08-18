# frozen_string_literal: true

module PageBlock
  module OrgSidebar
    # The organization admin sidebar. It stands in for the whole navbar on every page a
    # member with a passive organization sees, so it carries their account links too.
    class Component < ApplicationComponent
      COLLAPSE_BREAKPOINT = 1100
      MOBILE_BREAKPOINT = 760

      # The menu's own active vocabulary, at the granularities UI::ActiveLink resolves.
      # A filtered index carries query params, so its row matches on controller and action
      MATCHES = UI::ActiveLink::Component.match_table(auto: :path, match_controller: :controller,
        on_registrations_index: :controller_action)

      # A top-level row: the group toggles, the leaf links and the leaves with nothing
      # to link to all sit on this, so they stay the same height as each other
      ROW = "tw:mx-2 tw:flex tw:items-center tw:gap-[11px] tw:rounded-[11px] tw:px-3 tw:py-[9px] " \
        "tw:text-sm tw:font-bold tw:group-data-[collapsed=true]/sidebar:justify-center tw:max-[760px]:py-3.5"
      ROW_HOVER = "tw:hover:bg-gray-100 tw:dark:hover:bg-gray-700"
      ROW_CURRENT = "tw:bg-blue-50 tw:text-blue-600 tw:dark:bg-gray-700"
      ROW_RESTING = "tw:text-gray-900 tw:dark:text-gray-300"

      # A row inside a group, indented past its parent's icon
      CHILD = "tw:mx-2 tw:block tw:rounded-[10px] tw:py-2 tw:pr-3 tw:pl-11 tw:text-[13.5px] " \
        "tw:font-bold tw:whitespace-nowrap tw:max-[760px]:py-3.5"
      CHILD_RESTING = "tw:text-purple-500 tw:dark:text-purple-300"

      # One bar of the hamburgler, which folds into an X while the menu is open
      BAR = "tw:h-0.5 tw:w-5 tw:rounded-sm tw:bg-gray-900 tw:transition-all " \
        "tw:duration-200 tw:dark:bg-gray-300"

      def initialize(organization:, current_user:, current_user_or_unconfirmed_user: nil,
        controller_namespace: nil, controller_name: nil, action_name: nil,
        unregistered_parking_notification: nil)
        @organization = organization
        @current_user = current_user
        @current_user_or_unconfirmed_user = current_user_or_unconfirmed_user || current_user
        @controller_namespace = controller_namespace
        @controller_name = controller_name
        @action_name = action_name
        @unregistered_parking_notification = unregistered_parking_notification
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
        [ROW, ROW_HOVER, active ? ROW_CURRENT : ROW_RESTING].join(" ")
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

        @active_group = groups.find { |group| group_active?(group) }
      end

      def group_active?(group)
        group[:children].any? { |child| child[:type] == :link && active_link?(child) }
      end

      # Resolves the per-request active state the cached payload deferred, returning
      # true/false so the template never has to ask. Only two states are left that a path
      # can't answer: add-a-bike has to stay dark on the notification's variant of its own
      # url, and a sequence's pages are their own controller
      def active_link?(item)
        match = MATCHES[item[:active]]
        return UI::ActiveLink::Component.active?(path: item[:path], match:, view: helpers) if match

        case item[:active]
        when :on_bikes_new then on_bikes_new? && @unregistered_parking_notification.blank?
        when :on_registration_sequences
          organized_controller?("registration_sequences", "registration_sequence_pages")
        else item[:active] == true
        end
      end

      def organized_controller?(*controller_names)
        @controller_namespace == "organized" && controller_names.include?(@controller_name)
      end

      def on_bikes_new?
        organized_controller?("bikes") && @action_name == "new"
      end

      def avatar_url
        OrganizationDisplayer.avatar?(@organization) ? @organization.avatar.url(:medium) : nil
      end

      def icon(name, html_class:)
        helpers.inline_svg_tag("icons/#{name}.svg", class: html_class)
      end
    end
  end
end
