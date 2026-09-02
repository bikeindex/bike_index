# frozen_string_literal: true

module Pages
  module Register
    module Progress
      class Component < ApplicationComponent
        # steps: the flow's whole ordered list, so a step's place in it is its segment -
        # the report shifts everything after it, and only the list knows where it landed
        def initialize(steps:, step:)
          @steps = steps
          @step = step.to_s
        end

        private

        def number = @number ||= @steps.index(@step).to_i + 1

        def total = @steps.count
      end
    end
  end
end
