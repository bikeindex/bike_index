# frozen_string_literal: true

module Emails
  module PosRegistrationMerged
    class Component < ApplicationComponent
      def initialize(pos_registration_match:)
        @pos_bike = pos_registration_match.pos_bike
      end

      private

      def bike_type = @pos_bike.type

      def shop_name = @pos_bike.creation_organization&.short_name

      # The email the shop registered it to, which said to merge them
      def shop_email = EmailNormalizer.obfuscate(@pos_bike.current_ownership&.owner_email)
    end
  end
end
