# frozen_string_literal: true

module Org::ImpoundRecordsIndex
  class Component < ApplicationComponent
    include SortableHelper

    def initialize(pagy:, impound_records:, search_status:, search_unregisteredness:, time_range:, available_statuses:, current_organization:, search_proximity:, interpreted_params:)
      @pagy = pagy
      @impound_records = impound_records
      @search_status = search_status
      @search_unregisteredness = search_unregisteredness
      @time_range = time_range
      @available_statuses = available_statuses
      @current_organization = current_organization
      @search_proximity = search_proximity
      @interpreted_params = interpreted_params
    end

    private

    def kinds_for_select
      # This gets us the correct kinds for the current impound_record
      # e.g. no retrieved_by_owner for unregistered_parking_notification
      # Never include claim_approved or denied, even if they're valid update kinds - they have to be done through impound_claims
      # Also - never display "current" because it can't be updated that way
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

    def unregisteredness_dropdown_text
      case @search_unregisteredness
      when "only_registered" then translation(".only_user_registered")
      when "only_unregistered" then translation(".only_unregistered")
      else translation(".all_bikes")
      end
    end
  end
end
