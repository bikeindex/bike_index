# frozen_string_literal: true

module RegistrationShow
  module StolenDetails
    # Theft details for a stolen bike — mirrors the legacy show page's stolen block
    class Component < ApplicationComponent
      def initialize(bike:)
        @bike = bike
      end

      def render?
        @bike.status_stolen? && stolen_record.present?
      end

      private

      def stolen_record
        @stolen_record ||= @bike.current_stolen_record
      end
    end
  end
end
