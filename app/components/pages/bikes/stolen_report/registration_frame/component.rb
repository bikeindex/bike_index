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

          # The registration's details are in, and its emailed link is what's left before the report
          CONFIRM_EMAIL = "confirm_email"
          # The step the registration is on, where the register flow's names it
          def self.step_for(register_step) = (register_step.to_s == "2") ? "bike_details" : "bike_info"

          # step: one of REGISTRATION_STEPS, or CONFIRM_EMAIL
          # data: the step's controllers, which the register flow's shell carries for the whole page
          def initialize(b_param:, step:, title:, helper:, data: {})
            @b_param = b_param
            @step = (REGISTRATION_STEPS + [CONFIRM_EMAIL]).include?(step) ? step : REGISTRATION_STEPS.first
            @title = title
            @helper = helper
            @data = data.merge(controller: [data[:controller], "stolen-report--registration-header"].compact.join(" "),
              action: [data[:action], "hw-combobox:selection->stolen-report--registration-header#update",
                "form-persist:restored@window->stolen-report--registration-header#update"].compact.join(" "))
          end

          private

          # Waiting on the email, both registration steps are done and the report hasn't started
          def step_number(step = @step) = (step == CONFIRM_EMAIL) ? REGISTRATION_STEPS.count : STEPS.index(step) + 1

          def confirming? = @step == CONFIRM_EMAIL

          def position_text
            return @title if confirming?

            safe_join([translation(".step_of", number: step_number, total: STEPS.count), step_label(@step)], " · ")
          end

          def step_label(step) = render(Pages::Bikes::StolenReport::StepLabel::Component.new(step:, bike_type: @b_param.type_titleize))

          def done?(step) = confirming? ? REGISTRATION_STEPS.include?(step) : step_number(step) < step_number

          def current?(step) = step == @step
        end
      end
    end
  end
end
