# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Settings
        class Component < ApplicationComponent
          # Goes on the element wrapping this panel, which the caller renders — so class-level,
          # not an instance built only to read off
          def self.column_toggle_data_attributes(settings, controllers: nil)
            {controller: [controllers, "org--search org--search-column-toggle"].compact.join(" "),
             "org--search-column-toggle-default-columns-value": settings.initially_checked_columns.to_json}
          end

          def initialize(settings:, skip_search_and_filters: false)
            @settings = settings
            @skip_search_and_filters = skip_search_and_filters
          end
        end
      end
    end
  end
end
