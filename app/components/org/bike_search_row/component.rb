# frozen_string_literal: true

module Org::BikeSearchRow
  class Component < ApplicationComponent
    def initialize(bike:, organization:, additional_registration_fields: [])
      @bike = bike
      @organization = organization
      @additional_registration_fields = additional_registration_fields
    end

    private

    def bike_organization_note
      @bike_organization_note ||= BikeOrganizationNote.find_by(bike_id: @bike.id, organization_id: @organization.id)
    end
  end
end
