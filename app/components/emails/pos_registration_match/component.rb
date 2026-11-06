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

      def shop_name = @pos_bike.creation_organization&.short_name
    end
  end
end
