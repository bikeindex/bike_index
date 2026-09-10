# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Show
        class ComponentPreview < ApplicationComponentPreview
          def default
            render(Pages::Admin::Users::Show::Component.new(user: lookbook_user, bikes:, bikes_count: bikes.count))
          end

          private

          # What Admin::UsersController#calculate_user_bikes hands the component
          def bikes
            @bikes ||= lookbook_user.bikes.reorder(created_at: :desc).limit(10)
          end
        end
      end
    end
  end
end
