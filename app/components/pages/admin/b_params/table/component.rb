# frozen_string_literal: true

module Pages
  module Admin
    module BParams
      module Table
        class Component < ApplicationComponent
          def initialize(b_params:, sort_state: ComponentStructs::SortState.new,
            render_sortable: false, render_search: true)
            @b_params = b_params
            @sort_state = sort_state
            @render_sortable = render_sortable
            @render_search = render_search
          end
        end
      end
    end
  end
end
