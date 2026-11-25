# frozen_string_literal: true

module Pages
  module Admin
    module Graphs
      module Bikes
        # The bikes kind of the admin graphs page. Its charts fetch from GraphsController#variable
        # and its tables from #bikes_table, so the page renders without waiting on their counts
        class Component < ApplicationComponent
          def initialize(index:, sortable_params:, total_count:, ignored_only:, manufacturer:,
            searched_statuses:, default_statuses:, not_default_statuses:)
            @index = index
            @sortable_params = sortable_params
            @total_count = total_count
            @ignored_only = ignored_only
            @manufacturer = manufacturer
            @searched_statuses = searched_statuses
            @default_statuses = default_statuses
            @not_default_statuses = not_default_statuses
          end
        end
      end
    end
  end
end
