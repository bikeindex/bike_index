# frozen_string_literal: true

module Admin
  module Users
    module Show
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Admin::Users::Show::Component.new(user:, bikes:, bikes_count:))
        end
      end
    end
  end
end
