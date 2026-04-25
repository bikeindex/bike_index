# frozen_string_literal: true

module Org
  module RegistrationSearch
    class ComponentPreview < ApplicationComponentPreview
      # @display legacy_stylesheet true
      def default
        pagy = Pagy::Offset.new(count: bikes.count, page: 1, limit: 10)
        render Org::RegistrationSearch::Component.new(
          organization: lookbook_organization,
          pagy:,
          bikes:,
          per_page: 10,
          params: {},
          time_range: 1.year.ago..Time.current
        )
      end

      private

      def bikes
        return Bike.none if Rails.env.production? || lookbook_organization&.bikes.blank?

        lookbook_organization.bikes.limit(5)
      end
    end
  end
end
