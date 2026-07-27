# frozen_string_literal: true

module Register
  module Complete
    # The completion card: bike created, or awaiting email verification
    class Component < ApplicationComponent
      def initialize(b_param:, bike:)
        @b_param = b_param
        @bike = bike
      end
    end
  end
end
