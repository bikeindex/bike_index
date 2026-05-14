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

      private

      def current_org_to_param
        @current_org_to_param ||= @current_organization&.to_param
      end

      def notification_link(graduated_notification)
        return graduated_notification.id if @separate_secondary_notifications
        graduated_notification.primary_notification_id.presence || graduated_notification.id
      end

      def org_param_for(notification)
        @current_organization&.id == notification.organization_id ? current_org_to_param : notification.organization_id
      end
    end
  end
end
