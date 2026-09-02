# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Show
        class ComponentPreview < ApplicationComponentPreview
          def default
            render(Pages::Admin::Users::Show::Component.new(user:, bikes:, bikes_count:))
          end
        end
      end
    end
  end
end
