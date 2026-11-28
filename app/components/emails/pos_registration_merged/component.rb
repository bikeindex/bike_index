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
    end
  end
end
