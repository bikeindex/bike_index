# frozen_string_literal: true

module Org::BikeSearch
  class ComponentPreview < ApplicationComponentPreview
    # @display legacy_stylesheet true
    def default
      organization = lookbook_organization
      bikes = organization&.bikes&.limit(5) || Bike.none
      pagy = Pagy::Offset.new(count: bikes.count, page: 1, limit: 10)
      bike_search = Org::BikeSearch::Component.new(
        organization:,
        pagy:,
        per_page: 10,
        params: {},
        time_range: 1.year.ago..Time.current
      )
      render(bike_search) do
        bikes.map { |bike|
          content_tag(:tr) do
            render(Org::BikeSearchRow::Component.new(
              bike:,
              organization:,
              additional_registration_fields: bike_search.additional_registration_fields
            ))
          end
        }.join.html_safe
      end
    end
  end
end
