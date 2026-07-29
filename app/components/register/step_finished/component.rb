# frozen_string_literal: true

module Register
  module StepFinished
    # The completion card: bike created, or awaiting email verification
    class Component < ApplicationComponent
      def initialize(b_param:, current_user: nil)
        @b_param = b_param
        @current_user = current_user
        @bike = b_param.created_bike
      end

      private

      def cycle_type
        @b_param.type
      end
    end
  end
end
