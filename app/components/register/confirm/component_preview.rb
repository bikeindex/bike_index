# frozen_string_literal: true

module Register
  module Confirm
    # Where the emailed confirmation link lands
    class ComponentPreview < ApplicationComponentPreview
      # auto_submit off, otherwise the preview posts itself away as soon as it renders
      def default
        return production_notice("registration") if Rails.env.production?

        b_param = ::BParam.new(origin: "register_flow",
          params: {bike: {owner_email: lookbook_user&.email}}.as_json)
        render(Register::Confirm::Component.new(b_param:, token: "example-token", auto_submit: false))
      end
    end
  end
end
