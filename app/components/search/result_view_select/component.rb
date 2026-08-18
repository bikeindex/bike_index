# frozen_string_literal: true

module Search
  module ResultViewSelect
    class Component < ApplicationComponent
      def initialize(result_view: nil)
        @selected_result_view = SearchResults::Container::Component.permitted_result_view(result_view)
      end

      def call
        tag.div(class: "tw:mt-2 tw:flex tw:justify-end") do
          render(UI::Forms::RadioButtonGroup::Component.new(
            name: :search_result_view,
            entries: view_entries,
            selected: @selected_result_view,
            # The result component is chosen server-side, so switching layout re-runs the search
            data: {action: "change->search--form#submit"}
          ))
        end
      end

      private

      def view_entries
        [[:bike_box, "icons/list.svg", translation(".bike_box_view")],
          [:thumbnail, "icons/image.svg", translation(".thumbnail_view")]]
          .map { |value, icon, label| {value:, label: icon_label(icon, label)} }
      end

      # The chip is icon-only, so title carries the hint a visible label would. Not
      # inline_svg_tag's title:, which injects a <title> child - that one counts toward
      # the label's accessible name, doubling it against the sr-only span.
      def icon_label(icon, label)
        tag.span(title: label) do
          helpers.inline_svg_tag(icon, class: "tw:block tw:h-5 tw:w-5") + tag.span(label, class: "tw:sr-only")
        end
      end
    end
  end
end
