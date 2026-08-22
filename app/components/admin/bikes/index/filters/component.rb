# frozen_string_literal: true

module Admin
  module Bikes
    module Index
      module Filters
        # The nav row above the bikes index - the statuses toggle, the two toggles that are
        # just links, and the origin and POS dropdowns.
        class Component < ApplicationComponent
          # The order the dropdown lists them; "any (POS or not)" clears the param instead
          POS_TYPES = {"ascend_pos" => "Ascend", "lightspeed_pos" => "Lightspeed",
                       "any_pos" => "POS of any type", "no_pos" => "Not POS"}.freeze

          def initialize(index:, motorized: false, multi_delete: false,
            origin_search_type: nil, pos_search_type: nil, period: nil)
            @index = index
            @motorized = motorized
            @multi_delete = multi_delete
            @origin_search_type = origin_search_type
            @pos_search_type = pos_search_type
            @period = period
          end

          private

          def search_params = @index.sortable_search_params

          def any_origin_active? = @origin_search_type.blank?

          def origin_name
            any_origin_active? ? "Origin" : @origin_search_type.humanize
          end

          def pos_name
            return "POS" if @pos_search_type.blank?
            return "POS of any type" if @pos_search_type == "any_pos"

            @pos_search_type.humanize
          end

          # search_pos toggles off when its own value is clicked again
          def pos_path(value)
            url_for(search_params.merge(search_pos: (value unless @pos_search_type == value)))
          end

          def origin_path(origin)
            url_for(search_params.merge(search_origin: (origin unless @origin_search_type == origin)))
          end

          # A year or all-time period gives graphs with no detail in them
          def graphs_path
            search_period = %w[all year].include?(@period) ? "month" : @period
            admin_graphs_path(search_params.merge(search_kind: "bikes", period: search_period))
          end
        end
      end
    end
  end
end
