# frozen_string_literal: true

module Atoms
  module Admin
    module PaginationWithCount
      class Component < ApplicationComponent
        include GraphingHelper # for humanized_time_range_column

        def initialize(collection:, index:, count: nil, count_detail: nil, skip_total: false,
          viewing: nil, time_range_column: nil)
          @collection = collection
          @index = index
          @count = count
          @count_detail = count_detail
          @skip_total = skip_total
          @viewing = viewing
          @time_range_column = time_range_column || index.time_range_column
        end

        private

        def count
          return @count if @count.present?
          return @index.pagy.count if @index.pagy.respond_to?(:count)
          @collection.count
        end

        def viewing
          return @viewing if @viewing.present?
          if @collection.respond_to?(:table_name)
            @collection.table_name.humanize
          elsif @collection.first
            @collection.first.class.table_name.humanize
          else
            "records"
          end
        end

        def humanized_time_range_column_display
          humanized_time_range_column(@time_range_column, period: @index.period, render_chart: @index.render_chart)
        end

        def show_time_range?
          @index.time_range.present? && @index.period != "all"
        end

        def show_today_count?
          !@skip_total && @collection.respond_to?(:total_count)
        end

        def today_count
          @collection.where("#{@collection.table_name}.#{@time_range_column || "created_at"} >= ?", Time.current.beginning_of_day).total_count
        end

        def per_pages
          [10, 25, 50, 100, @index.per_page.to_i].uniq.sort
        end

        def per_page_select_id
          "per_page_select#{"-skiptotal" if @skip_total}"
        end
      end
    end
  end
end
