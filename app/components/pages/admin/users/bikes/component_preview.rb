# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Bikes
        class ComponentPreview < ApplicationComponentPreview
          def default
            bikes = Pages::Admin::Users::Tabs::Component.records(lookbook_user, :bikes).limit(10)
            render(Pages::Admin::Users::Bikes::Component.new(user: lookbook_user, bikes:, pagy: nil))
          end
        end
      end
    end
  end
end
