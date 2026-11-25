# frozen_string_literal: true

module Pages
  module Org
    module ImpoundRecords
      module Index
        # The impound records search's results: Search::Wrapper's card, with the multi-update
        # toggle where the registrations search has its export
        class Component < ApplicationComponent
          def initialize(pagy:, impound_records:, current_organization:, per_page:, params: {},
            sort_state: ComponentStructs::SortState.new, result_view: nil, multi_update_open: false)
            @pagy = pagy
            @impound_records = impound_records
            @current_organization = current_organization
            @per_page = per_page
            @params = params
            @sort_state = sort_state
            @result_view = result_view
            @multi_update_open = multi_update_open
          end
        end
      end
    end
  end
end
