# frozen_string_literal: true

module Pages
  module Admin
    module Organizations
      module Form
        module Locations
          class Component < ApplicationComponent
            def initialize(form_builder:)
              @form_builder = form_builder
              @organization = form_builder.object
            end

            private

            # A location the "Add a location" link just cloned has neither set
            def blank_location_attrs = {organization_id: @organization.id, name: @organization.name}
          end
        end
      end
    end
  end
end
