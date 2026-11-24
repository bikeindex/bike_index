# frozen_string_literal: true

module Emails
  module PosRegistrationMatch
    class Component < ApplicationComponent
      def initialize(bike:, pos_bike:, pos_registration_match:)
        @bike = bike
        @pos_bike = pos_bike
        @pos_registration_match = pos_registration_match
      end

      private

      def bike_type = @pos_bike.type

      def shop_name = @pos_bike.creation_organization&.short_name

      # Obscured, since the token's email may not be the owner's
      def other_email = EmailNormalizer.obfuscate(@bike.user&.email)

      def answer_url
        if @pos_registration_match.different_email?
          pos_registration_match_url(@pos_registration_match.token)
        else
          my_account_pos_registration_match_url(@pos_registration_match)
        end
      end
    end
  end
end
