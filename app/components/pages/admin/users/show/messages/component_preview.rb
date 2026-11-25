# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Show
        module Messages
          class ComponentPreview < ApplicationComponentPreview
            def default
              render(Pages::Admin::Users::Show::Messages::Component.new(user: lookbook_user))
            end
          end
        end
      end
    end
  end
end
