# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Show
        class ComponentPreview < ApplicationComponentPreview
          # @param active_tab select { choices: [bikes, marketplace_messages, memberships, alerts, payments, organization_roles, notifications, feedbacks, emails, ambassador_tasks] }
          def default(active_tab: :bikes)
            render(Pages::Admin::Users::Show::Component.new(user: lookbook_user, active_tab: active_tab.to_sym))
          end
        end
      end
    end
  end
end
