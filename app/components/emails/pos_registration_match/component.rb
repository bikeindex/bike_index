# frozen_string_literal: true

module Emails
  module PosRegistrationMatch
    class Component < ApplicationComponent
      def initialize(pos_registration_match:)
        @pos_registration_match = pos_registration_match
        @bike = Bike.unscoped.find(pos_registration_match.bike_id)
        @pos_bike = Bike.unscoped.find(pos_registration_match.pos_bike_id)
      end

      private

      def shop_name = @pos_bike.creation_organization&.short_name
    end
  end
end
