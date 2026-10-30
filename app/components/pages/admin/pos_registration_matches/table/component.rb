# frozen_string_literal: true

module Pages
  module Admin
    module PosRegistrationMatches
      module Table
        class Component < ApplicationComponent
          BUCKET_COLORS = {"merge_candidate" => :success, "review_candidate" => :warning}.freeze

          def initialize(collection:, sort_state: ComponentStructs::SortState.new, render_sortable: false)
            @collection = collection
            @sort_state = sort_state
            @render_sortable = render_sortable
          end
        end
      end
    end
  end
end
