# frozen_string_literal: true

module Pages
  module Org
    module Locations
      module Show
        # The locations settings page. Every Save button submits the one form; the org--locations
        # controller adds the unsaved indicators, add and remove. Its own add is why this doesn't
        # use UI::Forms::NestedFields, whose add button can't sit in the map bar.
        class Component < ApplicationComponent
          # The blank record's index, which org--locations swaps for a distinct one per added location
          CHILD_INDEX = "__INDEX__"

          def initialize(organization:, current_country_id:)
            @organization = organization
            @current_country_id = current_country_id
            @organization.locations.build if @organization.locations.load.empty?
          end

          private

          def form_url
            organization_manage_path(id: @organization.id, organization_id: @organization.to_param)
          end

          def form_data
            {controller: "org--locations", action: "input->org--locations#changed change->org--locations#changed hw-combobox:selection->org--locations#changed",
             "org--locations-show-on-map-value": @organization.show_on_map,
             "org--locations-summary-value": translation(".unsaved_summary"),
             "org--locations-one-location-value": translation(".one_location"),
             "org--locations-locations-value": translation(".locations", count: "%{count}"),
             "org--locations-map-setting-value": translation(".partner_map_setting")}
          end

          def fields_args = {organization: @organization, current_country_id: @current_country_id}

          def saved_fields(form_builder)
            form_builder.fields_for(:locations) do |builder|
              render(Pages::Org::Locations::Fields::Component.new(form_builder: builder, **fields_args))
            end
          end

          def blank_fields(form_builder)
            form_builder.fields_for(:locations, Location.new, child_index: CHILD_INDEX) do |builder|
              render(Pages::Org::Locations::Fields::Component.new(form_builder: builder, **fields_args))
            end
          end

          def partner_map_link
            link_to(translation(".bike_index_partner_map"), where_path, target: "_blank", rel: "noopener", class: "twlink")
          end

          def add_label
            safe_join([tag.span("+", aria: {hidden: true}), translation(".add_location")], " ")
          end
        end
      end
    end
  end
end
