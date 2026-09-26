# frozen_string_literal: true

module Pages
  module Register
    module Landing
      # Its form posts to the live register endpoints, so it's gated out of production
      class ComponentPreview < ApplicationComponentPreview
        def default
          return production_notice("registration") if Rails.env.production?

          b_param = ::BParam.new(origin: "register_flow")
          render(Pages::Register::Landing::Component.new(b_param:, current_user: lookbook_user,
            steps: ::BikeServices::Register.steps(b_param, sequence: nil),
            recoveries_count: 18_263, recoveries_value: 38_412_345, organizations_count: 1_000,
            bikes_count: 1_204_112))
        end
      end
    end
  end
end
