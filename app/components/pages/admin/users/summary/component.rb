# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Summary
        # The two lists under the tabs, on every admin screen scoped to one user
        class Component < ApplicationComponent
          def initialize(user:, current_country_id: nil)
            @user = user
            @current_country_id = current_country_id
          end
        end
      end
    end
  end
end
