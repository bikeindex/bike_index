# frozen_string_literal: true

module Emails
  module PartialRegisterConfirmation
    class Component < ApplicationComponent
      def initialize(b_param:)
        @b_param = b_param
      end

      private

      def expiration_days
        BParam::TOKEN_EXPIRATION.in_days.to_i
      end

      def tokenized_url
        confirm_register_url(b_param_token: @b_param.id_token,
          confirmation_token: @b_param.email_confirmation_token)
      end
    end
  end
end
