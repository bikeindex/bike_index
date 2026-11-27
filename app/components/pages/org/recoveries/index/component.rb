# frozen_string_literal: true

module Pages
  module Org
    module Recoveries
      module Index
        # The organization's recoveries: stolen records marked recovered, either near the
        # organization or of bikes registered with it, newest recovery first.
        class Component < ApplicationComponent
          DISTANCES = [5, 10, 25, 50, 100, 250].freeze
          DEFAULT_DISTANCE = 25
          # Display order
          RESULT_VIEWS = %i[table list cards].freeze
          FORM_ID = "recoveries_filters"

          def self.permitted_distance(distance)
            DISTANCES.include?(distance.to_i) ? distance.to_i : DEFAULT_DISTANCE
          end

          def self.permitted_result_view(result_view)
            view = result_view&.to_sym
            RESULT_VIEWS.include?(view) ? view : :list
          end

          def initialize(organization:, recoveries:, pagy:, distance:, only_organization:, organized_bike_ids:,
            result_view:, period:, start_time:, end_time:, sortable_search_params:, params:)
            @organization = organization
            @recoveries = recoveries
            @pagy = pagy
            @distance = distance
            @only_organization = only_organization
            @organized_bike_ids = organized_bike_ids.to_set
            @result_view = self.class.permitted_result_view(result_view)
            @period = period
            @start_time = start_time
            @end_time = end_time
            @sortable_search_params = sortable_search_params
            @params = params
          end

          private

          def distance_filterable? = @organization.search_coordinates_set?

          def distance_options
            options_for_select(DISTANCES.map { [translation(".distance_miles", count: it), it] }, @distance)
          end

          def organization_location
            address_record = @organization.default_address_record
            [address_record&.city, address_record&.region].compact_blank.join(", ")
          end

          def result_view_entries
            RESULT_VIEWS.map do |view|
              label = case view
              when :table then translation(".view_table")
              when :list then translation(".view_list")
              when :cards then translation(".view_cards")
              end
              ComponentStructs::Shapes.entry(label, href: result_view_path(view), active: @result_view == view)
            end
          end

          def result_view_path(result_view)
            organization_recoveries_path(@organization.to_param,
              @sortable_search_params.to_h.except("organization_id").merge(search_result_view: result_view))
          end

          def list_classes
            if @result_view == :cards
              "tw:grid tw:grid-cols-[repeat(auto-fill,minmax(14.5rem,1fr))] tw:gap-4"
            else
              "tw:flex tw:flex-col tw:gap-3"
            end
          end

          def distance_text(stolen_record)
            return if !distance_filterable? || stolen_record.latitude.blank?

            miles = Geocoder::Calculations.distance_between(@organization.search_coordinates,
              stolen_record.to_coordinates, units: :mi).round
            return translation(".under_a_mile_away") if miles.zero?

            translation(".miles_away_html", number: number_display(miles))
          end

          def organized?(stolen_record) = @organized_bike_ids.include?(stolen_record.bike_id)

          def sort_state
            ComponentStructs::SortState.new(sort: "recovered_at", direction: "desc")
          end
        end
      end
    end
  end
end
