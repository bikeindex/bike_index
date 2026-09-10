# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Cell
        class ComponentPreview < ApplicationComponentPreview
          # @!group User Cell Variants
          def default
            render(Pages::Admin::Users::Cell::Component.new(user: lookbook_user))
          end

          def missing_user
            render(Pages::Admin::Users::Cell::Component.new(user_id: 999999, email: "missing@example.com"))
          end

          def email_only
            render(Pages::Admin::Users::Cell::Component.new(email: "orphaned@example.com"))
          end

          def with_search
            render(Pages::Admin::Users::Cell::Component.new(user: lookbook_user, search_url: admin_users_path(user_id: lookbook_user.id), render_search: true))
          end

          def without_search
            render(Pages::Admin::Users::Cell::Component.new(user: lookbook_user, search_url: admin_users_path(user_id: lookbook_user.id), render_search: false))
          end
        end
      end
    end
  end
end
