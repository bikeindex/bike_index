# frozen_string_literal: true

module Pages
  module Register
    module Step2
      # Step 2 of the registration flow: the bike details form
      class Component < ApplicationComponent
        def initialize(b_param:, flow:, current_user: nil)
          @b_param = b_param
          @flow = flow
          @current_user = current_user
        end

        private

        def cycle_type
          @b_param.type
        end
      end
    end
  end
end
