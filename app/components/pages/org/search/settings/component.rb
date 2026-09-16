# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Settings
        class Component < ApplicationComponent
          def initialize(settings:, skip_search_and_filters: false)
            @settings = settings
            @skip_search_and_filters = skip_search_and_filters
          end
        end
      end
    end
  end
end
