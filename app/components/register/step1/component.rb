# frozen_string_literal: true

module Register
  module Step1
    # Step 1 of the registration flow: the quick-start form
    class Component < ApplicationComponent
      def initialize(b_param:)
        @b_param = b_param
      end
    end
  end
end
