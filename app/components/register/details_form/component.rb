# frozen_string_literal: true

module Register
  module DetailsForm
    # Step 2 of the registration flow: the bike details form
    class Component < ApplicationComponent
      def initialize(b_param:)
        @b_param = b_param
      end
    end
  end
end
