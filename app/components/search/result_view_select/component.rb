# frozen_string_literal: true

module Search
  module ResultViewSelect
    class Component < ApplicationComponent
      ICONS = {bike_box: "list", thumbnail: "image"}.freeze

      def initialize(result_view: nil)
        @selected_result_view = SearchResults::Container::Component.permitted_result_view(result_view)
      end

      private

      def entries
        ICONS.map { |view, icon| {value: view, label: icon_label(view, icon), title: view_name(view)} }
      end

      def icon_label(view, icon)
        safe_join([helpers.inline_svg_tag("icons/#{icon}.svg", class: "tw:block tw:h-5 tw:w-5"),
          tag.span(view_name(view), class: "tw:sr-only")])
      end

      def view_name(view)
        translation(".#{view}_view")
      end
    end
  end
end
