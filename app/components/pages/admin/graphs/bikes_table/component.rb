# frozen_string_literal: true

module Pages
  module Admin
    module Graphs
      module BikesTable
        # A table beside the admin bikes graphs. Without bikes it's the lazy frame that fetches
        # itself from GraphsController#bikes_table, which renders it again with them
        class Component < ApplicationComponent
          KINDS = %w[origin ios_version pos organization].freeze
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

          def initialize(kind:, sortable_params:, bikes: nil, time_range: nil)
            @kind = KINDS.include?(kind) ? kind : KINDS.first
            @sortable_params = sortable_params
            @bikes = bikes
            @time_range = time_range
          end

          private

          def lazy? = @bikes.nil?

          def src = bikes_table_admin_graphs_path(@sortable_params.merge(table_kind: @kind))

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
