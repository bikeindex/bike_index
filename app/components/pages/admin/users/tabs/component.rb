# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Tabs
        class Component < ApplicationComponent
          TABS = {edit: "Edit", bikes: "Bikes", payments: "Payments", organization_roles: "Organizations",
                  messages: "Messages", emails: "Emails", ambassador_tasks: "Ambassador tasks"}.freeze

          # The Messages tab's sections, which it counts together
          MESSAGE_KINDS = %i[marketplace_messages alerts notifications feedbacks].freeze

          def self.records(user, tab)
            case tab
            when :bikes then Bike.current_with_user_hidden.current_owner(user.id)
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

              ComponentStructs::Shapes.tab(tab_label(tab, label), tab_path(tab), active: @active == tab,
                count: (tab_counts[tab] unless payments_and_memberships?(tab)))
            end
          end

          # A member's Payments tab holds their memberships too, after the payments' own count
          def payments_and_memberships?(tab) = tab == :payments && tab_counts[:memberships].positive?

          def tab_label(tab, label)
            return label unless payments_and_memberships?(tab)

            safe_join([label, tag.small(number_display(tab_counts[:payments])),
              "& #{"membership".pluralize(tab_counts[:memberships])}"], " ")
          end

          # Keyed on the user, so a new bike or payment only shows once the user is next touched
          def tab_counts
            @tab_counts ||= Rails.cache.fetch(["admin_user_tab_counts", @user]) do
              counts = (TABS.keys - %i[edit messages] + MESSAGE_KINDS + %i[memberships]).to_h { [it, self.class.records(@user, it).count] }
              counts.merge(messages: counts.values_at(*MESSAGE_KINDS).sum)
            end
          end

          def tab_path(tab) = (tab == :edit) ? edit_admin_user_path(@user.id) : admin_user_path(@user.id, active_tab: tab)

          # Only ambassadors have tasks - except on its own page, which still renders (saying
          # so) and shouldn't lose its place in the row
          def render_tab?(tab) = tab != :ambassador_tasks || @active == tab || @user.ambassador?

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
