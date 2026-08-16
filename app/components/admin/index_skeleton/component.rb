# frozen_string_literal: true

module Admin
  module IndexSkeleton
    class Component < ApplicationComponent
      def initialize(
        viewing:,
        collection:,
        sortable_search_params: {},
        index_title: nil,
        nav_header_list_items: nil,
        skip_charting: false,
        rendered_chart: nil,
        render_sortable: true,
        time_range_column: nil,
        admin_search_form: nil,
        table_view: nil,
        chart_collection: nil,
        header_content: nil,
        count_detail: nil,
        render_chart: false,
        render_deleted: nil,
        pagy: nil,
        per_page: nil,
        time_range: nil,
        period: nil,
        start_time: nil,
        end_time: nil,
        user_subject: nil,
        bike: nil,
        marketplace_listing: nil,
        primary_activity: nil,
        current_organization: nil,
        params: {}
      )
        @collection = collection
        @viewing = viewing
        @sortable_search_params = sortable_search_params
        @index_title = index_title
        @nav_header_list_items = nav_header_list_items
        @skip_charting = skip_charting
        @rendered_chart = rendered_chart
        @render_sortable = render_sortable
        @time_range_column = time_range_column || "created_at"
        @admin_search_form = admin_search_form
        @table_view = table_view
        @chart_collection = chart_collection
        @header_content = header_content
        @count_detail = count_detail
        @render_chart = render_chart
        @render_deleted = render_deleted
        @pagy = pagy
        @per_page = per_page
        @time_range = time_range
        @period = period
        @start_time = start_time
        @end_time = end_time
        @user_subject = user_subject
        @bike = bike
        @marketplace_listing = marketplace_listing
        @primary_activity = primary_activity
        @current_organization = current_organization
        @params = params
      end

      private

      def show_chart?
        !@skip_charting && @render_chart
      end

      def default_chart
        data = UI::Chart::Component.time_range_counts(collection: @chart_collection, time_range: @time_range, column: @time_range_column)
        render(UI::Chart::Component.new(series: [{name: @viewing, data:}], time_range: @time_range))
      end

      def current_header_component
        Admin::CurrentHeader::Component.new(
          params: @params, viewing: @viewing,
          sortable_search_params: @sortable_search_params,
          user_subject: @user_subject, bike: @bike,
          marketplace_listing: @marketplace_listing,
          primary_activity: @primary_activity,
          current_organization: @current_organization
        )
      end

      def pagination_component(skip_total: false)
        Admin::PaginationWithCount::Component.new(
          collection: @collection, viewing: @viewing, skip_total:,
          count_detail: skip_total ? nil : @count_detail,
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

      def deleted_item_active?(value)
        value.nil? ? !deleted_active? : @render_deleted == value
      end

      def default_table_view
        helpers.render(partial: "table", locals: {collection: @collection, render_sortable: @render_sortable})
      end
    end
  end
end
