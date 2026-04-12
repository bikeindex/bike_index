# frozen_string_literal: true

module Org::RegistrationSearch
  class ComponentPreview < ApplicationComponentPreview
    # @display legacy_stylesheet true
    def default
      organization = lookbook_organization
      bikes = organization&.bikes&.limit(5) || Bike.none
      pagy = Pagy::Offset.new(count: bikes.count, page: 1, limit: 10)
      render Org::RegistrationSearch::Component.new(
        organization:,
        pagy:,
        bikes:,
        per_page: 10,
        params: {},
        time_range: 1.year.ago..Time.current
      )
    end
  end
end
