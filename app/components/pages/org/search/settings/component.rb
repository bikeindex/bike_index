# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Settings
        class Component < ApplicationComponent
          delegate :organization, :column_renames, :enabled_columns, :cycle_type,
            :search_params, :default_open?, to: :@settings

          def initialize(settings:, skip_search_and_filters: false)
            @settings = settings
            @skip_search_and_filters = skip_search_and_filters
          end
        end
      end
    end
  end
end
