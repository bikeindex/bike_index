# frozen_string_literal: true

module Org::BikeSearch
  class ComponentPreview < ApplicationComponentPreview
    def default
      organization = Organization.first
      bikes = organization&.bikes&.limit(5) || Bike.none
      pagy = Pagy::Offset.new(count: bikes.count, page: 1, limit: 10)
      render(Org::BikeSearch::Component.new(
        organization:,
        bikes:,
        pagy:,
        per_page: 10,
        params: {}
      ))
    end
  end
end
