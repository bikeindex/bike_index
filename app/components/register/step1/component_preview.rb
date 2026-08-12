# frozen_string_literal: true

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

      private

      def step_1(**bike)
        return production_notice("registration") if Rails.env.production?

        b_param = ::BParam.new(origin: "register_flow",
          params: {bike: {owner_email: lookbook_user&.email}.merge(bike).compact}.as_json)
        render(Register::Step1::Component.new(b_param:, current_user: lookbook_user,
          steps: ::BikeServices::Register.steps(b_param, sequence: ::BikeServices::Register.registration_sequence(b_param))))
      end
    end
  end
end
