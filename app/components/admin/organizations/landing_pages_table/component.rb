# frozen_string_literal: true

module Admin
  module Organizations
    module LandingPagesTable
      class Component < ApplicationComponent
        def initialize(collection:, sort_state: ComponentStructs::SortState.new,
          render_sortable: false, render_search: true)
          @collection = collection
          @sort_state = sort_state
          @render_sortable = render_sortable
          @render_search = render_search
        end
      end
    end
  end
end
