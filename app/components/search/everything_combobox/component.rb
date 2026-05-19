# frozen_string_literal: true

module Search
  module EverythingCombobox
    class Component < ApplicationComponent
      PER_PAGE = 15

      def initialize(selected_query_items_options:, query:, search_obj_name: nil)
        @opt_vals = opt_vals_for(selected_query_items_options)
        @query = query
        @search_obj_name = search_obj_name.presence || "Registrations"
      end

      private

      def opt_vals_for(selected_query_items_options)
        selected_query_items_options.map do |item|
          if item.is_a?(String)
            [item, item]
          else
            [item["text"], item["search_id"]]
          end
        end
      end

      # Comma-joined search_ids - the initial value of the combobox hidden field
      def selected_value
        @opt_vals.map(&:last).join(",")
      end

      def async_src
        helpers.search_combobox_options_path(search_obj_name: @search_obj_name, per_page: PER_PAGE)
      end

      def chips_src
        helpers.search_combobox_chips_path
      end
    end
  end
end
