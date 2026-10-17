# frozen_string_literal: true

module Atoms
  module Admin
    module TableCells
      module User
        class ComponentPreview < ApplicationComponentPreview
          # @!group User Cell Variants
          def default
            render(Atoms::Admin::TableCells::User::Component.new(user: lookbook_user))
          end

          def missing_user
            render(Atoms::Admin::TableCells::User::Component.new(user_id: 999999, email: "missing@example.com"))
          end

          def email_only
            render(Atoms::Admin::TableCells::User::Component.new(email: "orphaned@example.com"))
          end

          def with_search
            render(Atoms::Admin::TableCells::User::Component.new(user: lookbook_user, search_url: admin_users_path(user_id: lookbook_user.id), render_search: true))
          end

          def without_search
            render(Atoms::Admin::TableCells::User::Component.new(user: lookbook_user, search_url: admin_users_path(user_id: lookbook_user.id), render_search: false))
          end
        end
      end
    end
  end
end
