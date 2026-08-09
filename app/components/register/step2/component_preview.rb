# frozen_string_literal: true

module Register
  module Step2
    # The details form, reached once step 1 is submitted
    class ComponentPreview < ApplicationComponentPreview
      def default
        step_2
      end

      # The organization's own registration fields, under its heading
      def with_organization
        step_2(creation_organization_id: lookbook_organization&.id)
      end

      # Someone else's registration: it asks for their name, and the confirmation
      # link is still out
      def for_someone_else
        step_2(owner_email: "someone-else@bikeindex.org")
      end

      # A stolen registration is the one that asks for a phone number
      def stolen
        step_2(status: "status_stolen")
      end

      private

      def step_2(**bike)
        return production_notice("registration") if Rails.env.production?

        step_1_values = {owner_email: lookbook_user&.email,
                         manufacturer_id: ::Manufacturer.frame_makers.first&.id}
        b_param = ::BParam.new(origin: "register_flow",
          params: {bike: step_1_values.merge(bike).compact}.as_json)
        sequence = ::BikeServices::Register.registration_sequence(b_param)
        render(Register::Step2::Component.new(b_param:, sequence:, current_user: lookbook_user,
          steps: ::BikeServices::Register.steps(b_param, sequence:)))
      end
    end
  end
end
