# frozen_string_literal: true

module Emails
  module ConfirmationEmail
    class Component < ApplicationComponent
      def initialize(user:)
        @user = user
        @partner = user.partner_sign_up
      end

      private

      def tokenized_url
        confirm_users_url(id: @user.id, code: @user.confirmation_token, partner: @partner)
      end
    end
  end
end
