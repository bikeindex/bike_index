# frozen_string_literal: true

module Org::BikeSearch
  class ComponentPreview < ApplicationComponentPreview
    # @display legacy_stylesheet true
    def default
      organization = Organization.first
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
          render(Org::BikeSearchRow::Component.new(
            bike:,
            organization:,
            sortable_search_params: {},
            additional_registration_fields: bike_search.additional_registration_fields,
            show_avery_export: bike_search.show_avery_export?
          ))
        }.join.html_safe
      end
    end
  end
end
