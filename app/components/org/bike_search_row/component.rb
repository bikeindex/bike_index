# frozen_string_literal: true

module Org::BikeSearchRow
  class Component < ApplicationComponent
    def initialize(bike:, organization:, bike_sticker: nil, additional_registration_fields: [])
      @bike = bike
      @organization = organization
      @bike_sticker = bike_sticker
      @additional_registration_fields = additional_registration_fields
    end

    private

    def bike_organization_note
      @bike_organization_note ||= BikeOrganizationNote.find_by(bike_id: @bike.id, organization_id: @organization.id)
    end
  end
end
