# frozen_string_literal: true

module Org
  module GraduatedNotificationTable
    class Component < ApplicationComponent
      include Binxtils::SortableHelper

      def initialize(graduated_notifications:, current_organization:, render_sortable: false, render_remaining_at: false, skip_status: false, skip_email: false, skip_email_search: nil, separate_secondary_notifications: false)
        @graduated_notifications = graduated_notifications
        @current_organization = current_organization
        @render_sortable = render_sortable
        @render_remaining_at = render_remaining_at
        @skip_status = skip_status
        @skip_email = skip_email
        @skip_email_search = skip_email_search.nil? ? !render_sortable : skip_email_search
        @separate_secondary_notifications = separate_secondary_notifications
      end

      def org_param(notification)
        (@current_organization&.id == notification.organization_id) ? @current_organization&.to_param : notification.organization_id
      end

      def link_id(notification)
        return notification.id if @separate_secondary_notifications
        notification.primary_notification_id.presence || notification.id
      end

      def status_display(graduated_notification)
        status = graduated_notification.status_humanized&.titleize
        content_tag(:span, status.to_s, class: status_class(status))
      end

      private

      def status_class(status)
        case status
        when "Bike Graduated" then "text-info"
        when "Delivery Failure" then UI::Alert::Component::TEXT_CLASSES[:error]
        else "less-strong"
        end
      end
    end
  end
end
