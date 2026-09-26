# frozen_string_literal: true

module Pages
  module Register
    module Progress
      class Component < ApplicationComponent
        # flow: a step's place in it is its segment - the report shifts everything after
        # it, and only the flow knows where it landed
        def initialize(flow:, step:)
          @flow = flow
          @step = step
        end

        private

        def number = @number ||= @flow.position(@step)

        def total = @flow.count
      end
    end
  end
end
