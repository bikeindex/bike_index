# frozen_string_literal: true

module Pages
  module Register
    module Parts
      module Progress
        class ComponentPreview < ApplicationComponentPreview
          def step_1_of_2
            render(Pages::Register::Parts::Progress::Component.new(flow: ::BikeServices::RegisterFlow.new, step: 1))
          end

          # A stolen registration's flow: the report is the segment after the details
          def step_2_of_3
            render(Pages::Register::Parts::Progress::Component.new(flow: ::BikeServices::RegisterFlow.new(report: :after_details), step: 2))
          end
        end
      end
    end
  end
end
