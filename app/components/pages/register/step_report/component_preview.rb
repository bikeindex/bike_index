# frozen_string_literal: true

module Pages
  module Register
    module StepReport
      # The theft or the find, reached once the details are entered
      class ComponentPreview < ApplicationComponentPreview
        def default
          step_report(status: "status_stolen")
        end

        # A found vehicle asks for the impound record instead of the stolen one
        def found
          step_report(status: "status_impounded")
        end

        # The step re-rendered over what was entered before - coming back to it, or a
        # submission that didn't say when and where. Saved report data, not a finished report
        def with_report_data
          step_report(status: "status_stolen", stolen_record: {
            date_stolen: Time.current - 3.days, street: "1 Main St", city: "Chicago",
            theft_description: "Locked to a rack outside the coffee shop",
            locking_description: ::StolenRecord::LOCKING_DESCRIPTIONS.first
          })
        end

        private

        def step_report(status:, **params)
          return production_notice("registration") if Rails.env.production?

          b_param = ::BParam.new(origin: "register_flow", params: {
            bike: {owner_email: lookbook_user&.email, status:,
                   manufacturer_id: ::Manufacturer.frame_makers.first&.id}
          }.merge(params).as_json)
          sequence = ::BikeServices::Register.registration_sequence(b_param)
          render(Pages::Register::StepReport::Component.new(b_param:, sequence:,
            steps: ::BikeServices::Register.steps(b_param, sequence:)))
        end
      end
    end
  end
end
