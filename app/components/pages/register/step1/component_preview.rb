# frozen_string_literal: true

module Pages
  module Register
    module Step1
      # The flow's opening form. Every register preview renders against real
      # organizations and posts to the live register endpoints, so they're gated out
      # of production, where submitting one would start a real registration
      class ComponentPreview < ApplicationComponentPreview
        def default
          step_1
        end

        # Arrived on an organization's registration link
        def with_organization
          step_1(creation_organization_id: lookbook_organization&.id)
        end

        # Step 1 is only revisitable once submitted, so this is where "start over" appears
        def returned_from_step_2
          step_1(manufacturer_id: ::Manufacturer.frame_makers.first&.id, cycle_type: "e-scooter")
        end

        # Framed on an organization's landing page
        def embedded
          step_1(embed: true, creation_organization_id: lookbook_organization&.id)
        end

        def embedded_with_button_color
          step_1(embed: true, button_color: "#c9a227", creation_organization_id: lookbook_organization&.id)
        end

        private

        def step_1(embed: false, button_color: nil, **bike)
          return production_notice("registration") if Rails.env.production?

          b_param = ::BParam.new(origin: "register_flow",
            params: {bike: {owner_email: lookbook_user&.email}.merge(bike).compact}.as_json)
          render(Pages::Register::Step1::Component.new(b_param:, current_user: lookbook_user, embed:, button_color:,
            steps: ::BikeServices::Register.steps(b_param, sequence: ::BikeServices::Register.registration_sequence(b_param))))
        end
      end
    end
  end
end
