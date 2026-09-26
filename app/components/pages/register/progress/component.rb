# frozen_string_literal: true

module Pages
  module Register
    module Progress
      class Component < ApplicationComponent
        # A step's place in the flow is its segment - the report shifts everything after it
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
