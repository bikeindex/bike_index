# frozen_string_literal: true

module Admin::IndexSkeleton
  class Component < ApplicationComponent
    include SortableHelper
    include GraphingHelper

    def initialize(
      collection:,
      render_chart:,
      pagy:,
      per_page:,
      time_range:,
      period:,
      current_organization:,
      params:,
      viewing: nil,
      index_title: nil,
      nav_header_list_items: nil,
      skip_charting: false,
      rendered_chart: nil,
      render_sortable: true,
      time_range_column: "created_at",
      admin_search_form: nil,
      table_view: nil,
      chart_collection: nil,
      user_subject: nil,
      bike: nil,
      marketplace_listing: nil,
      primary_activity: nil
    )
      @collection = collection
      @viewing = viewing
      @index_title = index_title
      @nav_header_list_items = nav_header_list_items
      @skip_charting = skip_charting
      @rendered_chart = rendered_chart
      @render_sortable = render_sortable
      @time_range_column = time_range_column
      @admin_search_form = admin_search_form
      @table_view = table_view
      @chart_collection = chart_collection
      @render_chart = render_chart
      @pagy = pagy
      @per_page = per_page
      @time_range = time_range
      @period = period
      @user_subject = user_subject
      @bike = bike
      @marketplace_listing = marketplace_listing
      @primary_activity = primary_activity
      @current_organization = current_organization
      @params = params
    end

    private

    def viewing
      @viewing || helpers.controller_name.humanize
    end

    def show_chart?
      !@skip_charting && @render_chart
    end

    def default_chart
      helpers.column_chart(
        time_range_counts(collection: @chart_collection, column: @time_range_column),
        stacked: true, thousands: ","
      )
    end

    def current_header_component
      Admin::CurrentHeader::Component.new(
        params: @params, viewing: @viewing,
        user_subject: @user_subject, bike: @bike,
        marketplace_listing: @marketplace_listing,
        primary_activity: @primary_activity,
        current_organization: @current_organization
      )
    end

    def pagination_component(skip_total: false)
      Admin::PaginationWithCount::Component.new(
        collection: @collection, viewing:, skip_total:,
        pagy: @pagy, per_page: @per_page, time_range: @time_range,
        period: @period, time_range_column: @time_range_column, params: @params
      )
    end

    def default_table_view
      helpers.render(partial: "table", locals: {collection: @collection, render_sortable: @render_sortable})
    end
  end
end
