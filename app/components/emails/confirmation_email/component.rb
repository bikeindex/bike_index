# frozen_string_literal: true

module Emails
  module ConfirmationEmail
    class Component < ApplicationComponent
      def initialize(user:)
        @user = user
        @partner = user.partner_sign_up
        @return_to = user.signup_return_to
      end

      private

      def tokenized_url
        confirm_users_url(id: @user.id, code: @user.confirmation_token, partner: @partner, return_to: @return_to)
      end
    end
  end
end
