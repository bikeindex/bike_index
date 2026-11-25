# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Edit
        class ComponentPreview < ApplicationComponentPreview
          # The ban panel is collapsed, and the reason isn't required until it opens
          def default
            render(Pages::Admin::Users::Edit::Component.new(user: lookbook_user))
          end

          # What admin--user-edit-form leaves behind after the banned checkbox is ticked:
          # the panel open, with a reason required
          def banned
            user = lookbook_user
            user.banned = true

            render(Pages::Admin::Users::Edit::Component.new(user:))
          end

          def with_dev_info
            render(Pages::Admin::Users::Edit::Component.new(user: lookbook_user, display_dev_info: true))
          end
        end
      end
    end
  end
end
