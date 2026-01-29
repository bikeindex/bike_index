# frozen_string_literal: true

module Org::ImpoundRecordsIndex
  class Component < ApplicationComponent
    include SortableHelper

    def initialize(pagy:, impound_records:, search_status:, search_unregisteredness:, time_range:, available_statuses:, current_organization:)
      @pagy = pagy
      @impound_records = impound_records
      @search_status = search_status
      @search_unregisteredness = search_unregisteredness
      @time_range = time_range
      @available_statuses = available_statuses
      @current_organization = current_organization
    end

    private

    def kinds_for_select
      ImpoundRecordUpdate.kinds_humanized.except(:claim_approved, :claim_denied, :current, :expired)
    end

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
        "All statuses"
      else
        "#{@search_status.titleize} records"
      end
    end

    def display_status_for(status)
      if status != "current" && ImpoundRecord.statuses.include?(status)
        ImpoundRecord.statuses_humanized[status.to_sym]
      elsif status == "all"
        "All statuses"
      else
        "#{status.titleize} records"
      end
    end

    def unregisteredness_dropdown_text
      case @search_unregisteredness
      when "only_registered" then "Only user registered"
      when "only_unregistered" then "Only unregistered"
      else "All bikes"
      end
    end
  end
end
