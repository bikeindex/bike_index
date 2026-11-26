# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Show
        # The body of each Pages::Admin::Users::Tabs tab but Edit
        class Component < ApplicationComponent
          TABS = (Pages::Admin::Users::Tabs::Component::TABS.keys - %i[edit]).freeze

          def initialize(user:, active_tab:)
            raise_if_invalid_value!(:active_tab, active_tab, TABS)

            @user = user
            @active_tab = active_tab
          end

          private

          def records = Pages::Admin::Users::Tabs::Component.records(@user, @active_tab)

          def registration_organizations_link
            count = @user.user_registration_organizations.count
            link_to(safe_join([number_display(count), " registration ", "organization".pluralize(count)]),
              admin_user_registration_organizations_path(user_id: @user.id), class: "twlink")
          end

          # The assignments index lists only the completed ones, so it's what "complete" links to
          def ambassador_progress
            return "not an ambassador" unless @user.ambassador?

            link_to("#{Ambassador.find(@user.id).progress_count} complete",
              admin_ambassador_task_assignments_path(search_ambassador_id: @user.id), class: "twlink")
          end
        end
      end
    end
  end
end
