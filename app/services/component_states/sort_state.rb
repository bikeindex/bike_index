# frozen_string_literal: true

module ComponentStates
  # How a table is sorted, plus the search params its links have to carry. The three
  # travel together everywhere a sortable table is rendered, so they're passed as one.
  SortState = Data.define(:search_params, :sort, :direction) do
    def initialize(search_params: {}, sort: nil, direction: nil)
      super
    end

    def url_params(sort:, direction:)
      search_params.merge(sort:, direction:)
    end
  end
end
