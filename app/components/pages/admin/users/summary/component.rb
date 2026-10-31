# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Summary
        # The two lists under the tabs, on every admin screen scoped to one user
        class Component < ApplicationComponent
          def initialize(user:)
            @user = user
          end
        end
      end
    end
  end
end
