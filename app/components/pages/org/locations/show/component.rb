# frozen_string_literal: true

module Pages
  module Org
    module Locations
      module Show
        # Not UI::Forms::NestedFields: its add button can't sit in the map bar, and a removed
        # location collapses to a strip with Undo rather than hiding
        class Component < ApplicationComponent
          CHILD_INDEX = "__INDEX__"

          def initialize(organization:, current_country_id:)
            @organization = organization
            @current_country_id = current_country_id
          end

          private

          def form_url
            organization_manage_path(id: @organization.id, organization_id: @organization.to_param)
          end

          def form_data
            {controller: "org--locations", action: "input->org--locations#changed hw-combobox:selection->org--locations#changed",
             "org--locations-show-on-map-value": @organization.show_on_map,
             "org--locations-summary-value": translation(".unsaved_summary"),
             "org--locations-one-location-value": translation(".one_location"),
             "org--locations-locations-value": translation(".locations", count: "%{count}"),
             "org--locations-map-setting-value": translation(".partner_map_setting")}
          end

          # The organization's own, so a new location starts from its other addresses
          def new_location = Location.new(organization_id: @organization.id)

          # An organization without locations gets a blank one, unsaved
          def saved_fields(form_builder)
            location_fields(form_builder, @organization.locations.presence || [new_location])
          end

          def blank_fields(form_builder)
            location_fields(form_builder, new_location, child_index: CHILD_INDEX)
          end

          def location_fields(form_builder, *records, **options)
            form_builder.fields_for(:locations, *records, **options) do |builder|
              render(Pages::Org::Locations::Fields::Component.new(form_builder: builder, organization: @organization,
                current_country_id: @current_country_id))
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
