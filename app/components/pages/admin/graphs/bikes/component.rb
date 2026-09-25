# frozen_string_literal: true

module Pages
  module Admin
    module Graphs
      module Bikes
        # The bikes kind of the admin graphs page. Its charts fetch from GraphsController#variable,
        # which reads the constants below so the charts and tables agree
        class Component < ApplicationComponent
          # Each series carries its own, so the table's swatches match without the two agreeing
          # on an order across the chart's separate request. The shared chart palette runs out
          # well before Ownership.origins does
          ORIGIN_COLORS = Ownership.origins.zip(UI::Chart::Component::COLORS + %w[#0891B2 #65A30D
            #EA580C #4F46E5 #9333EA #0D9488 #CA8A04 #E11D48 #2563EB #16A34A]).to_h.freeze
          POS_SEARCH_KINDS = %w[lightspeed_pos ascend_pos does_not_need_pos no_pos].freeze
          IOS_VERSION_SQL = "ownerships.registration_info ->> 'ios_version'"

          def self.ios_version_bikes(bikes)
            bikes.joins(:ownerships).where("#{IOS_VERSION_SQL} IS NOT NULL").group(IOS_VERSION_SQL)
          end

          def initialize(bikes:, index:, sortable_params:, total_count:, ignored_only:, manufacturer:,
            searched_statuses:, default_statuses:, not_default_statuses:)
            @bikes = bikes
            @index = index
            @sortable_params = sortable_params
            @total_count = total_count
            @ignored_only = ignored_only
            @manufacturer = manufacturer
            @searched_statuses = searched_statuses
            @default_statuses = default_statuses
            @not_default_statuses = not_default_statuses
          end

          private

          # Ownership.origins order breaks count ties, so the rows don't reshuffle between
          # loads. Distinct: a bike has an ownership per transfer
          def origin_bike_counts
            origins = Ownership.origins
            counts = @bikes.joins(:ownerships).group("ownerships.origin").distinct.count(:id)
            origins.index_with { counts[it] || 0 }.sort_by { |origin, count| [-count, origins.index(origin)] }
          end

          def ios_version_bike_counts
            self.class.ios_version_bikes(@bikes).distinct.count(:id).sort_by { |version, count| [-count, version] }
          end
        end
      end
    end
  end
end
