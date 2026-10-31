# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Header
        # Everything above the body on an admin screen scoped to one user: the tab row, and the
        # summary of the user under it
        class Component < ApplicationComponent
          def initialize(user:, active:, current_country_id: nil)
            @user = user
            @active = active
            @current_country_id = current_country_id
          end
        end
      end
    end
  end
end
