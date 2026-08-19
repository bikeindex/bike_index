# frozen_string_literal: true

module ComponentStates
  # Everything an admin index page knows about its own request — the same values on every
  # one of them, so `ControllerHelpers#admin_index_state` builds it once and each index view
  # hands it over whole. What varies per page (the collection, what it's called, the table)
  # stays an argument of its own.
  IndexState = Data.define(
    :params, :sort_state, :render_chart, :render_deleted, :pagy, :per_page, :time_range,
    :period, :start_time, :end_time, :current_organization, :user_subject, :bike,
    :marketplace_listing, :primary_activity, :time_range_column
  ) do
    def initialize(params: {}, sort_state: ComponentStates::SortState.new, render_chart: false,
      render_deleted: nil, pagy: nil, per_page: nil, time_range: nil, period: nil, start_time: nil,
      end_time: nil, current_organization: nil, user_subject: nil, bike: nil,
      marketplace_listing: nil, primary_activity: nil, time_range_column: nil)
      super
    end

    def sortable_search_params = sort_state.search_params
  end
end
