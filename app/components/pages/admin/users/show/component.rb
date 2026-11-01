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

          def registration_organizations_count = @registration_organizations_count ||= @user.user_registration_organizations.count
        end
      end
    end
  end
end
