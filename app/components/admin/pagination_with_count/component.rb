# frozen_string_literal: true

module Admin::PaginationWithCount
  class Component < ApplicationComponent
    include GraphingHelper # for humanized_time_range_column

    def initialize(collection:, count: nil, skip_total: false, skip_today: false, skip_pagination: false, humanized_time_range_column_override: nil, viewing: nil, pagy: nil, per_page: nil, time_range: nil, period: nil, time_range_column: nil, params: {})
      @collection = collection
      @count = count
      @skip_total = skip_total
      @skip_today = skip_today
      @skip_pagination = skip_pagination
      @humanized_time_range_column_override = humanized_time_range_column_override
      @viewing = viewing
      @pagy = pagy
      @per_page = per_page
      @time_range = time_range
      @period = period
      @time_range_column = time_range_column
      @params = params
    end

    private

    def count
      return @count if @count.present?
      return @pagy.count if @pagy.respond_to?(:count)
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
      if @humanized_time_range_column_override.present?
        @humanized_time_range_column_override
      else
        humanized_time_range_column(@time_range_column)
      end
    end

    def show_time_range?
      @time_range.present? && @period != "all"
    end

    def show_today_count?
      !@skip_total && @collection.respond_to?(:total_count)
    end

    def today_count
      @collection.where("#{@collection.table_name}.#{@time_range_column || "created_at"} >= ?", Time.current.beginning_of_day).total_count
    end

    def per_pages
      [10, 25, 50, 100, @per_page.to_i].uniq.sort
    end

    def per_page_select_id
      "per_page_select#{"-skiptotal" if @skip_total}"
    end
  end
end
