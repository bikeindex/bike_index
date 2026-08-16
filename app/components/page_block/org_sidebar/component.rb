# frozen_string_literal: true

module PageBlock
  module OrgSidebar
    # The organization admin sidebar. It stands in for the whole navbar on every
    # page a member with a passive organization sees, so it carries the account
    # links the settings dropdown used to.
    class Component < ApplicationComponent
      COLLAPSE_BREAKPOINT = 1100
      MOBILE_BREAKPOINT = 760

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
        active_group = items.find { |item| item[:type] == :group && group_active?(item) }
        return group_active?(group) if active_group

        group == items.find { |item| item[:type] == :group }
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
