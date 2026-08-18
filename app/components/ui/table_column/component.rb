# frozen_string_literal: true

module UI
  module TableColumn
    class Component < ApplicationComponent
      NBSP = "\u00A0"

      attr_reader :sortable, :cell_block

      def initialize(label: nil, sortable: nil, sort_indicator: nil, classes: nil, header_classes: nil, lower_right: nil, &block)
        @label = label
        @sortable = sortable
        @sort_indicator = sort_indicator
        @classes = classes
        @header_classes = header_classes
        @lower_right = lower_right
        @cell_block = block
      end

      # Renders cell content for a record. The block should yield the captured
      # cell content (executed in the parent Table component's view context).
      def render_cell(record)
        cell_content = yield(record)
        return cell_content unless @lower_right

        lower_right_content = @lower_right.call(record)
        content_tag(:div, class: "tw:relative tw:min-h-5") do
          safe_join([
            cell_content,
            content_tag(:small, safe_join([NBSP.html_safe, lower_right_content]),
              class: "tw:absolute tw:-right-0.5 tw:-bottom-1 tw:text-xs tw:text-gray-400")
          ])
        end
      end

      def render_header(render_sortable:, current_sort:, current_direction:, sortable_url:, sort_icon:)
        if sortable.present? && render_sortable
          render_sort_link(current_sort:, current_direction:, sortable_url:, sort_icon:)
        elsif @sort_indicator.present? && @sort_indicator == current_sort
          safe_join([header_label, NBSP, sort_icon.call(current_direction)])
        else
          header_label
        end
      end

      def th_classes(bordered:)
        classes = ["tw:px-1 tw:py-2"]
        if bordered
          classes << "tw:border-b tw:border-l tw:border-t tw:border-gray-200 tw:dark:border-gray-600"
        end
        classes << @classes if @classes
        classes << @header_classes if @header_classes
        classes.join(" ")
      end

      def td_classes(bordered:)
        classes = ["tw:px-1 tw:py-1"]
        classes << if bordered
          "tw:border-b tw:border-l tw:border-gray-200 tw:dark:border-gray-700"
        else
          "tw:border-b tw:border-gray-100 tw:dark:border-gray-700"
        end
        classes << @classes if @classes
        classes.join(" ")
      end

      private

      def header_label
        return @label unless @label.nil?
        @sortable&.gsub(/_(id|at)\z/, "")&.titleize
      end

      def render_sort_link(current_sort:, current_direction:, sortable_url:, sort_icon:)
        title = header_label
        sorted_by_this = @sortable == current_sort
        direction = (sorted_by_this && current_direction == "desc") ? "asc" : "desc"

        arrow_spans = if sorted_by_this
          [content_tag(:span, sort_icon.call(current_direction), class: "tw:group-hover:hidden"),
            content_tag(:span, sort_icon.call(direction), class: "tw:hidden tw:group-hover:inline tw:opacity-50")]
        else
          [content_tag(:span, sort_icon.call(direction), class: "tw:opacity-0 tw:group-hover:opacity-50 tw:transition-opacity")]
        end

        # data-active rather than an `active` class: that's what the is-active variant matches
        link_to(sortable_url.call(@sortable, direction), class: "twlink tw:group",
          data: {active: sorted_by_this || nil}) do
          safe_join([title, NBSP, *arrow_spans])
        end
      end
    end
  end
end
