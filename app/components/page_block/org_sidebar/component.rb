# frozen_string_literal: true

module PageBlock
  module OrgSidebar
    # The organization admin sidebar. It stands in for the whole navbar on every
    # page a member with a passive organization sees, so it carries the account
    # links the settings dropdown used to.
    class Component < ApplicationComponent
      COLLAPSE_BREAKPOINT = 1100
      MOBILE_BREAKPOINT = 760

      # A top-level row: the group toggles, the leaf links and the leaves with nothing
      # to link to all sit on this, so they stay the same height as each other
      ROW = "tw:mx-2 tw:flex tw:items-center tw:gap-[11px] tw:rounded-[11px] tw:px-3 tw:py-[9px] " \
        "tw:text-sm tw:font-bold tw:group-data-[collapsed=true]/sidebar:justify-center tw:max-[760px]:py-3.5"
      ROW_HOVER = "tw:hover:bg-gray-100 tw:dark:hover:bg-gray-700"
      ROW_CURRENT = "tw:bg-blue-50 tw:text-blue-600 tw:dark:bg-gray-700"
      ROW_RESTING = "tw:text-gray-900 tw:dark:text-gray-300"

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

      # Resolves the per-request active state the cached payload deferred. Returns
      # true/false, so the template never has to ask the active_link helper.
      def active_link?(item)
        case item[:active]
        when :auto then current_path?(item[:path])
        when :match_controller then current_controller?(item[:path])
        when :on_registrations_index then organized_controller?("registrations") && @action_name == "index"
        when :on_bikes_new then on_bikes_new? && @unregistered_parking_notification.blank?
        when :on_bikes_new_with_parking_notification then on_bikes_new? && @unregistered_parking_notification.present?
        when :on_registration_sequences
          organized_controller?("registration_sequences", "registration_sequence_pages")
        else item[:active] == true
        end
      end

      def current_path?(path)
        request_path == path.split("?").first
      end

      # match_controller items stay lit across a controller's member and edit pages
      def current_controller?(path)
        request_path.start_with?(path.split("?").first)
      end

      def request_path
        @request_path ||= request&.path.to_s
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
