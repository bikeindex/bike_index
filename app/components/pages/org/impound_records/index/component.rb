# frozen_string_literal: true

module Pages
  module Org
    module ImpoundRecords
      module Index
        class Component < ApplicationComponent
          def initialize(pagy:, impound_records:, search_status:, time_range:, period:, current_organization:, current_user: nil, params: {}, sort_state: ComponentStructs::SortState.new, multi_update_open: false)
            @pagy = pagy
            @impound_records = impound_records
            @search_status = search_status
            @time_range = time_range
            @period = period
            @current_organization = current_organization
            @current_user = current_user
            @params = params
            @sort_state = sort_state
            @multi_update_open = multi_update_open
          end

          private

          def skip_resolved
            ImpoundRecord.active_statuses.include?(@search_status)
          end

          def render_status
            %w[all resolved].include?(@search_status)
          end
        end
      end
    end
  end
end
