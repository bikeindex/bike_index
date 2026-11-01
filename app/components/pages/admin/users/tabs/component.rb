# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Tabs
        class Component < ApplicationComponent
          TABS = {edit: "Edit", bikes: "Bikes", deleted_bikes: "Deleted bikes", marketplace_messages: "Messages",
                  memberships: "Memberships", alerts: "Alerts", payments: "Payments", organization_roles: "Organizations",
                  notifications: "Notifications", feedbacks: "Feedbacks", emails: "Emails",
                  ambassador_tasks: "Ambassador tasks"}.freeze

          # These tabs are another controller's index, filtered to this user - which renders the
          # header through Pages::Admin::IndexSkeleton's user_tab:. The rest but edit are the
          # users show action's.
          INDEX_PATHS = {marketplace_messages: :admin_marketplace_messages_path, memberships: :admin_memberships_path,
                         alerts: :admin_user_alerts_path, payments: :admin_payments_path,
                         notifications: :admin_notifications_path, feedbacks: :admin_feedbacks_path}.freeze

          def self.records(user, tab)
            case tab
            when :bikes then Bike.current_with_user_hidden.current_owner(user.id)
            when :deleted_bikes then Bike.unscoped.current_owner(user.id).only_deleted
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

          def tabs
            TABS.filter_map do |tab, label|
              next unless render_tab?(tab)

              ComponentStructs::Shapes.tab(label, tab_path(tab), count: tab_counts[tab], active: @active == tab)
            end
          end

          # Keyed on the user, so a new bike or payment only shows once the user is next touched
          def tab_counts
            @tab_counts ||= Rails.cache.fetch(["admin_user_tab_counts", @user]) do
              (TABS.keys - %i[edit]).to_h { [it, self.class.records(@user, it).count] }
            end
          end

          def tab_path(tab)
            return edit_admin_user_path(@user.id) if tab == :edit
            return admin_user_path(@user.id, active_tab: tab) unless INDEX_PATHS.key?(tab)

            public_send(INDEX_PATHS[tab], user_id: @user.id)
          end

          # Hidden with nothing behind them - except on their own page, which keeps its place
          def render_tab?(tab)
            return true if @active == tab

            case tab
            when :ambassador_tasks then @user.ambassador?
            when :deleted_bikes then tab_counts[:deleted_bikes].positive?
            else true
            end
          end

          def last_email_errored = @last_email_errored ||= @user.user_emails.last_email_errored.to_a

          # present? loads the association, so the template and the badges reuse it
          def alerts?
            @user.deleted? || @user.banned? || last_email_errored.present? || @user.email_bans_active.present?
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
