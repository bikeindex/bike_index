# frozen_string_literal: true

module Pages
  module Org
    module Locations
      module Fields
        # One location's card. Its dirty, removed and badge states are all driven by
        # Pages::Org::Locations::Show's org--locations controller, which finds the pieces
        # by data-slot, so the markup here is only the starting state it computes.
        class Component < ApplicationComponent
          def initialize(form_builder:, organization:, current_country_id:)
            @form_builder = form_builder
            @organization = organization
            @current_country_id = current_country_id
            @location = form_builder.object
          end

          private

          def new_record? = @location.new_record?

          def display_name = @location.name.presence || translation(".new_location")

          # A location that has no name yet starts with the organization's
          def name_value = @location.name.presence || @organization.name

          def impound_enabled? = @organization.enabled?("impound_bikes")

          def on_map? = @organization.show_on_map && @location.publicly_visible

          def impound? = impound_enabled? && @location.impound_location

          def default_impound? = impound? && @location.default_impound_location

          def address_record = @location.find_or_build_address_record(current_country_id: @current_country_id)

          def wrapper_classes
            ["tw:rounded-xl tw:transition-shadow tw:duration-300", ("tw:ring-2 tw:ring-blue-400" if new_record?)].compact.join(" ")
          end

          def wrapper_data = {"org--locations-target": "location", new_record: new_record?}

          # Hidden at load unless the state it stands for is already true
          def hidden_unless(shown) = shown ? nil : "tw:hidden"

          def checkbox(attribute, slot:, label: nil, &)
            render(UI::Forms::Checkbox::Component.new(form_builder: @form_builder, attribute:, label:,
              html_options: {data: {slot:}}), &)
          end
        end
      end
    end
  end
end
