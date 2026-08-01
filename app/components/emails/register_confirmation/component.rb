# frozen_string_literal: true

module Emails
  module RegisterConfirmation
    class Component < ApplicationComponent
      def initialize(b_param:)
        @b_param = b_param
      end

      private

      def expiration_days
        BParam::TOKEN_EXPIRATION.in_days.to_i
      end

      def color_and_brand = @b_param.color_and_brand

      # The confirmation token only ever exists in this email - never rendered
      # anywhere the registrant's browser could have shown it first
      def tokenized_url
        confirm_register_url(b_param_token: @b_param.id_token,
          confirmation_token: @b_param.email_confirmation_token)
      end
    end
  end
end
