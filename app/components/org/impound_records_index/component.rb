# frozen_string_literal: true

module Org
  module ImpoundRecordsIndex
    class Component < ApplicationComponent
      def initialize(pagy:, impound_records:, search_status:, search_unregisteredness:, humanized_time_range:, available_statuses:, current_organization:, current_user: nil, params: {}, sort_state: ComponentStructs::SortState.new, multi_update_open: false)
        @pagy = pagy
        @impound_records = impound_records
        @search_status = search_status
        @search_unregisteredness = search_unregisteredness
        @humanized_time_range = humanized_time_range
        @available_statuses = available_statuses
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

      def status_dropdown_text
        if @search_status != "current" && ImpoundRecord.statuses.include?(@search_status)
          ImpoundRecord.statuses_humanized[@search_status.to_sym]
        elsif @search_status == "all"
          translation(".all_statuses")
        else
          translation(".status_records", status: @search_status.titleize)
        end
      end

      def display_status_for(status)
        if status != "current" && ImpoundRecord.statuses.include?(status)
          ImpoundRecord.statuses_humanized[status.to_sym]
        elsif status == "all"
          translation(".all_statuses")
        else
          translation(".status_records", status: status.titleize)
        end
      end

      def status_query(status)
        {search_status: (status == @available_statuses.first) ? [status, nil] : status}
      end

      def unregisteredness_dropdown_text
        case @search_unregisteredness
        when "only_registered" then translation(".only_user_registered")
        when "only_unregistered" then translation(".only_unregistered")
        else translation(".all_bikes")
        end
      end
    end
  end
end
