# frozen_string_literal: true

module SortableHelper
  include Binxtils::SortableHelper

  def default_search_keys
    super + [:time_range_column, :organization_id, :serial, :stolenness,
      :location, :distance, :primary_activity, query_items: []]
  end
end
