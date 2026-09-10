# frozen_string_literal: true

module Pages
  module Register
    module StepConfirm
      # Where the emailed confirmation link lands
      class ComponentPreview < ApplicationComponentPreview
        def default
          return production_notice("registration") if Rails.env.production?

          b_param = ::BParam.new(origin: "register_flow",
            params: {bike: {owner_email: lookbook_user&.email}}.as_json)
          render(Pages::Register::StepConfirm::Component.new(b_param:, token: "example-token"))
        end
      end
    end
  end
end
