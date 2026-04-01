# frozen_string_literal: true

module UI
  module TableColumn
    # ViewComponent representing a single table column. The table renders this
    # component once per cell via `render(col.for_record(record))`.
    class Component < ApplicationComponent
      ARROW_UP = "\u2191"
      ARROW_DOWN = "\u2193"
      NBSP = "\u00A0"

      attr_reader :sortable

      def initialize(label: nil, sortable: nil, classes: nil, header_classes: nil, lower_right: nil, &block)
        @label = label
        @sortable = sortable
        @classes = classes
        @header_classes = header_classes
        @lower_right = lower_right
        @cell_block = block
      end

      def for_record(record)
        @record = record
        self
      end

      def call
        cell_content = capture { instance_exec(@record, &@cell_block) }
        return cell_content unless @lower_right

        lower_right_content = instance_exec(@record, &@lower_right)
        content_tag(:div, class: "tw:relative tw:min-h-5") do
          safe_join([
            cell_content,
            NBSP.html_safe,
            content_tag(:small, lower_right_content,
              class: "tw:absolute tw:-right-0.5 tw:-bottom-1 tw:text-xs tw:text-gray-400")
          ])
        end
      end

      def render_header(render_sortable:, current_sort:, current_direction:, sortable_url:)
        if sortable.present? && render_sortable
          render_sort_link(current_sort:, current_direction:, sortable_url:)
        else
          header_label
        end
      end

      def th_classes(index, total:, bordered:)
        classes = ["tw:border-0 tw:bg-gray-200 tw:px-1 tw:py-2 tw:dark:bg-gray-700"]
        if bordered
          classes << "tw:border-b tw:border-r tw:border-t tw:border-gray-300 tw:dark:border-gray-600"
          classes << "tw:border-l" if index == 0
        end
        classes << "tw:rounded-tl-sm" if index == 0
        classes << "tw:rounded-tr-sm" if index == total - 1
        classes << @classes if @classes
        classes << @header_classes if @header_classes
        classes.join(" ")
      end

      def td_classes(index, total:, bordered:, last_row:)
        classes = ["tw:border-0 tw:px-1 tw:py-1"]
        if bordered
          classes << "tw:border-b tw:border-r tw:border-gray-200 tw:dark:border-gray-700"
          classes << "tw:border-l" if index == 0
        else
          classes << "tw:border-b tw:border-gray-100 tw:dark:border-gray-700"
        end
        classes << "tw:rounded-bl-sm" if last_row && index == 0
        classes << "tw:rounded-br-sm" if last_row && index == total - 1
        classes << @classes if @classes
        classes.join(" ")
      end

      private

      def header_label
        @label || @sortable&.gsub(/_(id|at)\z/, "")&.titleize
      end

      def render_sort_link(current_sort:, current_direction:, sortable_url:)
        title = @label || @sortable.gsub(/_(id|at)\z/, "").titleize
        direction = (@sortable == current_sort && current_direction == "desc") ? "asc" : "desc"
        css = "twlink"

        if @sortable == current_sort
          css += " active"
          arrow_spans = [
            content_tag(:span, arrow_for(current_direction), class: "tw:group-hover/sort:hidden"),
            content_tag(:span, arrow_for(direction), class: "tw:hidden tw:group-hover/sort:inline tw:opacity-50")
          ]
        else
          arrow_spans = [
            content_tag(:span, arrow_for(direction), class: "tw:opacity-0 tw:group-hover/sort:opacity-50 tw:transition-opacity")
          ]
        end

        link_to(sortable_url.call(@sortable, direction), class: "#{css} tw:group/sort") do
          safe_join([title, NBSP, *arrow_spans])
        end
      end

      def arrow_for(direction)
        (direction == "desc") ? ARROW_DOWN : ARROW_UP
      end
    end
  end
end
