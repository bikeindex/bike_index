# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Header
        class ComponentPreview < ApplicationComponentPreview
          def default
            render(Pages::Admin::Users::Header::Component.new(user: lookbook_user, active: :edit))
          end
        end
      end
    end
  end
end
