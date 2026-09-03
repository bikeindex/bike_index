# frozen_string_literal: true

module Pages
  module Admin
    module IndexSkeleton
      class Component < ApplicationComponent
        def initialize(
          index:,
          collection:,
          viewing:,
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
          count_detail: nil
        )
          @index = index
          @collection = collection
          @viewing = viewing
          @index_title = index_title
          @nav_header_list_items = nav_header_list_items
          @skip_charting = skip_charting
          @rendered_chart = rendered_chart
          @render_sortable = render_sortable
          @time_range_column = time_range_column || index.time_range_column || "created_at"
          @admin_search_form = admin_search_form
          @table_view = table_view
          @chart_collection = chart_collection
          @header_content = header_content
          @count_detail = count_detail
        end

        private

        def sortable_search_params = @index.sortable_search_params

        # "Manage" is the first thing a narrow screen can spare
        def index_title
          @index_title.presence ||
            safe_join([tag.span("Manage", class: "tw:hidden tw:lg:inline"), " ", @viewing])
        end

        def show_chart?
          !@skip_charting && @index.render_chart
        end

        def default_chart
          data = UI::Chart::Component.time_range_counts(collection: @chart_collection, time_range: @index.time_range, column: @time_range_column)
          render(UI::Chart::Component.new(series: [{name: @viewing, data:}], time_range: @index.time_range))
        end

        def index_info_component
          Pages::Admin::Headers::IndexInfo::Component.new(index: @index, viewing: @viewing)
        end

        def pagination_component(skip_total: false)
          Atoms::Admin::PaginationWithCount::Component.new(
            index: @index, collection: @collection, viewing: @viewing, skip_total:,
            count_detail: skip_total ? nil : @count_detail, time_range_column: @time_range_column
          )
        end

        def show_deleted_link?
          !@index.render_deleted.nil?
        end

        def deleted_active?
          @index.render_deleted.present? && @index.render_deleted != false
        end

        def deleted_label
          case @index.render_deleted
          when "including" then "Including deleted"
          when "only" then "Only deleted"
          else "deleted"
          end
        end

        def default_table_view
          render(partial: "table", locals: {collection: @collection, render_sortable: @render_sortable})
        end
      end
    end
  end
end
