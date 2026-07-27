# frozen_string_literal: true

module Register
  module Progress
    class ComponentPreview < ApplicationComponentPreview
      def step_1_of_2
        render(Register::Progress::Component.new(step: 1, total: 2))
      end

      def step_2_of_3
        render(Register::Progress::Component.new(step: 2, total: 3))
      end
    end
  end
end
