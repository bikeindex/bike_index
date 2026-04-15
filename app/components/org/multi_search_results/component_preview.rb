# frozen_string_literal: true

module Org::MultiSearchResults
  class ComponentPreview < ApplicationComponentPreview
    # @display legacy_stylesheet true
    def default
      pagy = Pagy::Offset.new(count: bikes.count, page: 1, limit: 10)
      render Component.new(
        organization: lookbook_organization,
        query: "SERIAL111",
        chip_id: "chip_0",
        pagy:,
        bikes:,
        interpreted_params: {},
        per_page: 10
      )
    end

    private

    def bikes
      return Bike.none if Rails.env.production? || lookbook_organization&.bikes.blank?

      lookbook_organization.bikes.limit(5)
    end
  end
end
