# frozen_string_literal: true

module Pages
  module Register
    module Views
      module Landing
        # Its form posts to the live register endpoints, so it's gated out of production
        class ComponentPreview < ApplicationComponentPreview
          def default
            return production_notice("registration") if Rails.env.production?

            b_param = ::BParam.new(origin: "register_flow")
            render(Pages::Register::Views::Landing::Component.new(b_param:, current_user: lookbook_user,
              flow: ::BikeServices::Register.flow(b_param, course: nil), stripe_prices: ::StripePrice.active_for(::Currency.default)))
          end
        end
      end
    end
  end
end
