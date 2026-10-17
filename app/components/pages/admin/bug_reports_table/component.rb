# frozen_string_literal: true

module Pages
  module Admin
    module BugReportsTable
      class Component < ApplicationComponent
        def initialize(collection:, searchable_tags:, sort_state: ComponentStructs::SortState.new, render_sortable: false)
          @collection = collection
          @searchable_tags = searchable_tags
          @sort_state = sort_state
          @render_sortable = render_sortable
        end
      end
    end
  end
end
