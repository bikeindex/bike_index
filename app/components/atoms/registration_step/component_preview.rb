# frozen_string_literal: true

module Atoms
  module RegistrationStep
    class ComponentPreview < ApplicationComponentPreview
      def step_2 = render(Atoms::RegistrationStep::Component.new(b_param: b_param))

      def awaiting_email_confirmation
        render(Atoms::RegistrationStep::Component.new(b_param: b_param({details_completed: true})))
      end

      def finished
        render(Atoms::RegistrationStep::Component.new(b_param: b_param({details_completed: true}, created_bike_id: 42)))
      end

      private

      def b_param(extra = {}, created_bike_id: nil)
        BParam.new(origin: "register_flow", created_bike_id:,
          params: {bike: {owner_email: "owner@example.com", manufacturer_id: 12}}.merge(extra).as_json)
      end
    end
  end
end
