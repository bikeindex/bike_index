# frozen_string_literal: true

module Search
  module EverythingCombobox
    class Component < ApplicationComponent
      def initialize(selected_query_items_options:, query:, search_obj_name: nil)
        @opt_vals = selected_query_items_options.map { |item| BikeSearchable.query_item_display_value(item) }
        @query = query
        @search_obj_name = search_obj_name.presence || "Registrations"
      end

      private

      # Comma-joined search_ids - the initial value of the combobox hidden field
      def selected_value
        @opt_vals.map(&:last).join(",")
      end

      def async_src
        helpers.search_combobox_options_path(search_obj_name: @search_obj_name)
      end

      def chips_src
        helpers.search_combobox_chips_path
      end
    end
  end
end
