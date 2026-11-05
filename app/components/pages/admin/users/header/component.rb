# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Header
        # Everything above the body on an admin screen scoped to one user: the tab row, and the
        # summary of the user under it
        class Component < ApplicationComponent
          def initialize(user:, active:)
            @user = user
            @active = active
          end
        end
      end
    end
  end
end
