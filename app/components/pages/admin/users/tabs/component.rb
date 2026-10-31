# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Tabs
        class Component < ApplicationComponent
          TABS = {edit: "Edit", bikes: "Bikes", marketplace_messages: "Messages", memberships: "Memberships",
                  alerts: "Alerts", payments: "Payments", organization_roles: "Organizations",
                  notifications: "Notifications", feedbacks: "Feedbacks", emails: "Emails",
                  ambassador_tasks: "Ambassador tasks"}.freeze

          # These tabs are another controller's index, filtered to this user - which renders the
          # header through Pages::Admin::IndexSkeleton's user_tab:. The rest but edit are
          # Pages::Admin::Users::Show tabs.
          INDEX_PATHS = {bikes: :admin_bikes_path, marketplace_messages: :admin_marketplace_messages_path,
                         memberships: :admin_memberships_path, alerts: :admin_user_alerts_path,
                         payments: :admin_payments_path, notifications: :admin_notifications_path,
                         feedbacks: :admin_feedbacks_path}.freeze

          # What a tab counts
          def self.records(user, tab)
            case tab
            when :bikes then user.bikes
            when :marketplace_messages then MarketplaceMessage.for_user(user)
            when :memberships then user.memberships
            when :alerts then user.user_alerts
            when :payments then user.payments.paid
            when :organization_roles then user.organization_roles
            when :notifications then Notification.notifications_sent_or_received_by(user)
            when :feedbacks then user.feedbacks
            when :emails then user.user_emails
            when :ambassador_tasks then user.ambassador_task_assignments
            end
          end

          def initialize(user:, active:)
            raise_if_invalid_value!(:active, active, TABS.keys)

            @user = user
            @active = active
          end

          private

          def title
            safe_join([@user.display_name,
              render(Atoms::Admin::Badges::User::Component.new(user: @user))].reject(&:blank?), " ")
          end

          def tabs
            TABS.filter_map do |tab, label|
              next unless render_tab?(tab)

              count = self.class.records(@user, tab).count unless tab == :edit
              ComponentStructs::Shapes.tab(label, tab_path(tab), count:, active: @active == tab)
            end
          end

          def tab_path(tab)
            return edit_admin_user_path(@user.id) if tab == :edit
            return admin_user_path(@user.id, active_tab: tab) unless INDEX_PATHS.key?(tab)

            # Payments' period otherwise defaults to the last year
            period = "all" if tab == :payments
            public_send(INDEX_PATHS[tab], user_id: @user.id, period:)
          end

          # Only ambassadors have tasks - except on its own page, which still renders (saying
          # so) and shouldn't lose its place in the row
          def render_tab?(tab) = tab != :ambassador_tasks || @active == tab || @user.ambassador?

          def last_email_errored = @last_email_errored ||= @user.user_emails.last_email_errored

          def alerts?
            @user.deleted? || @user.banned? || last_email_errored.any? || @user.email_bans_active.any?
          end

          def non_admin_view_link
            return unless @user.show_bikes?

            render(UI::ButtonLink::Component.new(text: "non-admin view", size: :sm, href: user_path(@user)))
          end
        end
      end
    end
  end
end
