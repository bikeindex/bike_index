# frozen_string_literal: true

module Admin::IndexSkeleton
  class Component < ApplicationComponent
    include SortableHelper
    include GraphingHelper

    def initialize(
      collection: nil,
      viewing: nil,
      index_title: nil,
      nav_header_list_items: nil,
      skip_charting: false,
      rendered_chart: nil,
      render_sortable: true,
      time_range_column: nil,
      admin_search_form: nil,
      table_view: nil,
      chart_collection: nil
    )
      @collection_arg = collection
      @viewing_arg = viewing
      @index_title = index_title
      @nav_header_list_items = nav_header_list_items
      @skip_charting = skip_charting
      @rendered_chart = rendered_chart
      @render_sortable = render_sortable
      @time_range_column_arg = time_range_column
      @admin_search_form = admin_search_form
      @table_view = table_view
      @chart_collection = chart_collection
    end

    def before_render
      ctrl = controller
      @render_chart = ctrl.instance_variable_get(:@render_chart)
      @pagy = ctrl.instance_variable_get(:@pagy)
      @per_page = ctrl.instance_variable_get(:@per_page)
      @time_range = ctrl.instance_variable_get(:@time_range)
      @period = ctrl.instance_variable_get(:@period)
      @user_subject = ctrl.instance_variable_get(:@user_subject)
      @bike = ctrl.instance_variable_get(:@bike)
      @marketplace_listing = ctrl.instance_variable_get(:@marketplace_listing)
      @primary_activity = ctrl.instance_variable_get(:@primary_activity)
    end

    private

    def collection
      @collection_arg || controller.instance_variable_get(:@collection)
    end

    def viewing
      @viewing_arg || helpers.controller_name.humanize
    end

    def time_range_column
      @time_range_column_arg || controller.instance_variable_get(:@time_range_column) || "created_at"
    end

    def show_chart?
      !@skip_charting && @render_chart
    end

    def default_chart
      helpers.column_chart(
        time_range_counts(collection: @chart_collection, column: time_range_column),
        stacked: true, thousands: ","
      )
    end

    def current_header_component
      Admin::CurrentHeader::Component.new(
        params:, viewing: @viewing_arg,
        user_subject: @user_subject, bike: @bike,
        marketplace_listing: @marketplace_listing,
        primary_activity: @primary_activity,
        current_organization: (helpers.current_organization if helpers.respond_to?(:current_organization))
      )
    end

    def pagination_component(skip_total: false)
      Admin::PaginationWithCount::Component.new(
        collection:, viewing:, skip_total:,
        pagy: @pagy, per_page: @per_page, time_range: @time_range,
        period: @period, time_range_column:, params:
      )
    end

    def default_table_view
      helpers.render(partial: "table", locals: {collection:, render_sortable: @render_sortable})
    end
  end
end
