# frozen_string_literal: true

module Pages
  module Bikes
    module StolenReport
      module RegistrationFrame
        # The register flow's two steps for an owner reporting their own theft, framed as the start
        # of the stolen report: the report's header, its rail and progress, all nine steps counted.
        # The step's own form is the content
        class Component < ApplicationComponent
          REGISTRATION_STEPS = Pages::Bikes::StolenReport::Wizard::Component::REGISTRATION_STEPS
          STEPS = REGISTRATION_STEPS + Pages::Bikes::StolenReport::Wizard::Component::STEPS

          # The step the registration is on, where the register flow's names it
          def self.step_for(register_step) = (register_step.to_s == "2") ? "bike_details" : "bike_info"
          # data: the step's controllers, which the register flow's shell carries for the whole page
          def initialize(b_param:, step:, title:, helper:, data: {})
            @b_param = b_param
            @step = REGISTRATION_STEPS.include?(step) ? step : REGISTRATION_STEPS.first
            @title = title
            @helper = helper
            @data = data
          end


          private

          def step_number(step = @step) = STEPS.index(step) + 1

          def step_label(step) = render(Pages::Bikes::StolenReport::StepLabel::Component.new(step:, bike_type: @b_param.type_titleize))

          def done?(step) = step_number(step) < step_number

          def current?(step) = step == @step
        end
      end
    end
  end
end
