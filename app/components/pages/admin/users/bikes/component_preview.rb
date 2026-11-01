# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Bikes
        class ComponentPreview < ApplicationComponentPreview
          # @param active_tab select { choices: [bikes, deleted_bikes] }
          def default(active_tab: :bikes)
            active_tab = active_tab.to_sym
            bikes = Pages::Admin::Users::Tabs::Component.records(lookbook_user, active_tab).limit(10)
            render(Pages::Admin::Users::Bikes::Component.new(user: lookbook_user, active_tab:, bikes:, pagy: nil))
          end
        end
      end
    end
  end
end
