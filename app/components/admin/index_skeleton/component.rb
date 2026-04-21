# frozen_string_literal: true

module Admin::IndexSkeleton
  class Component < ApplicationComponent
    include Binxtils::SortableHelper

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
      @collection = collection
      @viewing = viewing
      @index_title = index_title
      @nav_header_list_items = nav_header_list_items
      @skip_charting = skip_charting
      @rendered_chart = rendered_chart
      @render_sortable = render_sortable
      @time_range_column_override = time_range_column
      @admin_search_form = admin_search_form
      @table_view = table_view
      @chart_collection = chart_collection
    end

    def before_render
      @collection ||= controller.instance_variable_get(:@collection)
      @render_chart = controller.instance_variable_get(:@render_chart)
      @pagy = controller.instance_variable_get(:@pagy)
      @per_page = controller.instance_variable_get(:@per_page)
      @render_deleted = controller.instance_variable_get(:@render_deleted)
      @time_range = controller.instance_variable_get(:@time_range)
      @period = controller.instance_variable_get(:@period)
      @start_time = controller.instance_variable_get(:@start_time)
      @end_time = controller.instance_variable_get(:@end_time)
      @time_range_column = @time_range_column_override || controller.instance_variable_get(:@time_range_column) || "created_at"
      @user_subject = controller.instance_variable_get(:@user_subject)
      @bike = controller.instance_variable_get(:@bike)
      @marketplace_listing = controller.instance_variable_get(:@marketplace_listing)
      @primary_activity = controller.instance_variable_get(:@primary_activity)
      @current_organization = helpers.respond_to?(:current_organization) ? helpers.current_organization : nil
      @params = helpers.params
    end

    private

    def viewing
      @viewing || helpers.controller_name.humanize
    end

    def show_chart?
      !@skip_charting && @render_chart
    end

    def default_chart
      data = UI::Chart::Component.time_range_counts(collection: @chart_collection, time_range: @time_range, column: @time_range_column)
      render(UI::Chart::Component.new(series: [{name: viewing, data:}], time_range: @time_range))
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

    def show_deleted_link?
      !@render_deleted.nil?
    end

    def deleted_active?
      @render_deleted.present? && @render_deleted != false
    end

    def deleted_label
      case @render_deleted
      when "including" then "Including deleted"
      when "only" then "Only deleted"
      else "deleted"
      end
    end

    def deleted_item_class(value)
      if value.nil? ? !deleted_active? : @render_deleted == value
        "active"
      end
    end

    def default_table_view
      helpers.render(partial: "table", locals: {collection: @collection, render_sortable: @render_sortable})
    end
  end
end
