# frozen_string_literal: true

module Admin
  module OrganizationsIndex
    module Filters
      # The organizations index's nav header: the kind and POS pickers, plus the paid
      # toggle and the link to a new organization.
      class Component < ApplicationComponent
        include Binxtils::SortableHelper

        # broken_pos sits with the three groupings rather than with the individual kinds
        POS_GROUPINGS = %w[with_pos without_pos broken_pos].freeze

        def initialize(search_paid:)
          @search_paid = search_paid
        end

        private

        def kind = helpers.params[:search_kind]

        def pos_kind = helpers.params[:search_pos]

        def kind_name = kind.present? ? kind.humanize : "Kind"

        def pos_name = pos_kind.present? ? pos_kind.humanize : "POS"

        def pos_entries = POS_GROUPINGS + Organization.pos_kinds

        # A filter entry stands for the params it applies, so it links away from itself to
        # clear the filter - which is what match: :query compares
        def filter_link(text, param, value)
          render(UI::ActiveLink::Component.new(text:, match: :query, query: {param => value},
            path: url_for(sortable_search_params.merge(param => value))))
        end

        def paid_path = url_for(sortable_search_params.merge(search_paid: !@search_paid))
      end
    end
  end
end
