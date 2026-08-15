# frozen_string_literal: true

module Admin
  module OrganizationForm
    module LocationFields
      # TODO: use organized/manages/location_fields instead of this
      class Component < ApplicationComponent
        def initialize(form_builder:, organization:)
          @form_builder = form_builder
          @organization = organization
          @location = form_builder.object

          # A location the "Add a location" link just cloned has none of these set
          @location.organization_id ||= @organization.id
          @location.name ||= @organization.name
          @location.address_record = @location.find_or_build_address_record
        end

        private

        def publicly_visible_label
          return Location.human_attribute_name(:publicly_visible) if @organization.allowed_show?

          safe_join([Location.human_attribute_name(:publicly_visible),
            tag.small("org not shown on map, checking this won't change that", class: "text-warning ml-1")], " ")
        end
      end
    end
  end
end
