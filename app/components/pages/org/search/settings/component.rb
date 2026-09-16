# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Settings
        class Component < ApplicationComponent
          delegate :organization, :column_renames, :enabled_columns, :cycle_type, :search_params,
            :default_open?, :search_stickers, :search_address, :search_status, to: :@settings, private: true

          def initialize(settings:, skip_search_and_filters: false)
            @settings = settings
            @skip_search_and_filters = skip_search_and_filters
          end
        end
      end
    end
  end
end
