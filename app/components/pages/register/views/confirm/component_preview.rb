# frozen_string_literal: true

module Pages
  module Register
    module Views
      module Confirm
        # Where the emailed confirmation link lands
        class ComponentPreview < ApplicationComponentPreview
          def default
            return production_notice("registration") if Rails.env.production?

            render(Pages::Register::Views::Confirm::Component.new(b_param:, token: "example-token", accept_terms: true))
          end

          def signed_in_as_someone_else
            return production_notice("registration") if Rails.env.production?

            render(Pages::Register::Views::Confirm::Component.new(b_param:, token: "example-token", accept_terms: true,
              signed_in_as: "a-much-longer-address-than-most@bikeindex.org"))
          end

          private

          def b_param = ::BParam.new(origin: "register_flow", params: {bike: {owner_email: lookbook_user&.email}}.as_json)
        end
      end
    end
  end
end
