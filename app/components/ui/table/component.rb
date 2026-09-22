# frozen_string_literal: true

module UI
  module Table
    class Component < ApplicationComponent
      # Template Dependency: UI::TableColumn::Component
      # Cell blocks are instance_exec'd, so this is how they reach the sort state
      attr_reader :sort_state

      # Pass cache_key (normally self.class.cache_digest) to enable per-cell fragment caching.
      # cache_records: mirror the controller's `includes`, or the cells serve those records stale.
      # cache_rows: one fragment per row instead - for a column set cache_key can't enumerate
      def initialize(records:, sort_state: ComponentStructs::SortState.new, cache_key: nil, cache_records: nil, cache_rows: false, classes: nil, unbordered: false, render_sortable: false, sticky: false)
        @records = records
        @sort_state = sort_state
        @cache_key = cache_key
        @cache_records = cache_records
        @cache_rows = cache_rows
        @classes = classes
        @bordered = !unbordered
        @render_sortable = render_sortable
        @sticky = sticky
        @columns = []
        @shared_fragment_columns = Set.new
      end

      # A cell block is instance_exec'd here, so it can't reach the calling component's
      # methods - a caller that needs one binds it to a local first
      def column(label: nil, sortable: nil, sort_indicator: nil, classes: nil, header_classes: nil, lower_right: nil, footer: nil, &block)
        @columns << UI::TableColumn::Component.new(label:, sortable:, sort_indicator:, classes:, header_classes:, lower_right:, footer:, &block)
        nil
      end

      def before_render
        content
      end

      private

      def sortable_url(sort, direction)
        url_for(@sort_state.url_params(sort:, direction:))
      end

      def current_sort
        @current_sort ||= sortable_columns.include?(@sort_state.sort) ? @sort_state.sort : default_sort_column
      end

      def current_direction
        @sort_state.direction || "desc"
      end

      def default_sort_column
        @columns.find { |c| c.sortable }&.sortable
      end

      def sortable_columns
        @columns.filter_map(&:sortable)
      end

      def cache_records_for(record) = Array(@cache_records&.call(record))

      # A cell rendering a shared_cache_if fragment stays out of the table's cache, whose key
      # would pin a copy per table - so that miss isn't written, and the rest of its column
      # skips the read
      def render_cell(col, column_index, record, row_records)
        return render_cell_content(col, record) unless cache_cells? && @shared_fragment_columns.exclude?(column_index)

        name = cache_fragment_name(localized_cache_key(cell_cache_key(column_index, record, row_records)))
        fragment = controller.read_fragment(name)
        return fragment.html_safe if fragment

        shared_before = ApplicationComponent.shared_fragments_rendered
        content = ActionView::Helpers::CacheHelper::CachingRegistry.track_caching { render_cell_content(col, record) }
        if ApplicationComponent.shared_fragments_rendered > shared_before
          @shared_fragment_columns << column_index
        else
          controller.write_fragment(name, content.to_s)
        end
        content
      end

      def render_cell_content(col, record)
        col.render_cell(record) { |r| capture { instance_exec(r, &col.cell_block) } }
      end

      def cache_cells?
        return @cache_cells if defined?(@cache_cells)

        @cache_cells = @cache_key.present? && !@cache_rows && controller.respond_to?(:perform_caching) && controller.perform_caching
      end

      def cache_rows? = @cache_rows && @cache_key.present?

      # The index rather than the column, so two cells of one record don't share a fragment.
      # It puts every flag that adds or drops a column in cache_key, or later cells read
      # their neighbour's; `cell_block.source_location` is no way out, a loop reuses one block
      def cell_cache_key(column_index, record, cache_records)
        [@cache_key, column_index, record, *cache_records]
      end

      def footer?
        @columns.any?(&:footer)
      end

      def sortable_table
        sortable_columns.any?
      end

      # Stacking + background so the header paints over scrolled rows.
      def sticky_th_classes
        @sticky ? "tw:relative tw:z-10 tw:bg-gray-50 tw:dark:bg-gray-700" : nil
      end

      def table_classes
        [
          "ui-table tw:min-w-full tw:text-left tw:leading-[1.25] tw:border-separate tw:border-spacing-0",
          ("ui-table-bordered" if @bordered),
          @classes
        ].compact.join(" ")
      end
    end
  end
end
