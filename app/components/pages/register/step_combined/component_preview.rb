# frozen_string_literal: true

module Pages
  module Register
    module StepCombined
      # The whole registration on one page, for the organization switch that asks for
      # both steps at once
      class ComponentPreview < ApplicationComponentPreview
        def default
          combined
        end

        # The organization's own registration fields, under its heading
        def with_organization
          combined(creation_organization_id: lookbook_organization&.id)
        end

        private

        def combined(**bike)
          return production_notice("registration") if Rails.env.production?

          b_param = ::BParam.new(origin: "register_flow",
            params: {bike: {owner_email: lookbook_user&.email}.merge(bike).compact}.as_json)
          render(Pages::Register::StepCombined::Component.new(b_param:, current_user: lookbook_user,
            steps: ::BikeServices::Register.steps(b_param, sequence: nil, single_page: true)))
        end
      end
    end
  end
end
