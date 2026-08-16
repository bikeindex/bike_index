# frozen_string_literal: true

module Admin
  module OrganizationLandingPagesTable
    class Component < ApplicationComponent
      def initialize(collection:, sortable_search_params: {}, sort: nil, sort_direction: nil,
        render_sortable: false, render_search: true)
        @collection = collection
        @sortable_search_params = sortable_search_params
        @sort = sort
        @sort_direction = sort_direction
        @render_sortable = render_sortable
        @render_search = render_search
      end
    end
  end
end
