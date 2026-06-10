# frozen_string_literal: true

module Org
  module ImpoundRecordUpdateForm
    class Component < ApplicationComponent
      # Pass an impound_record for a single-record update, or omit it for the
      # multi-update form (which wraps the records table passed as a block).
      def initialize(current_organization:, impound_record: nil, impound_record_update: nil, approved_impound_claim: nil, parking_notification: nil, multi_update_open: false)
        @current_organization = current_organization
        @impound_record = impound_record
        @impound_record_update = impound_record_update || ImpoundRecordUpdate.new
        @approved_impound_claim = approved_impound_claim
        @parking_notification = parking_notification
        @multi = impound_record.blank?
        @multi_update_open = multi_update_open
      end

      private

      def form_url
        record_id = @multi ? "multi_update" : @impound_record.display_id
        organization_impound_record_path(record_id, organization_id: @current_organization)
      end

      # Multi mode: table-multi-checkbox drives select-all, and submit is
      # validated by org--impound-update-multi (blocks empty submissions)
      def form_data
        return {} unless @multi

        {controller: "table-multi-checkbox", action: "submit->org--impound-update-multi#validate"}
      end

      # The kind <select> change is handled by org--impound-update (field
      # visibility) and, in multi mode, org--impound-update-multi (checkboxes)
      def kind_select_data
        data = {"org--impound-update-target": "kindSelect", action: "change->org--impound-update#applyKind"}
        return data unless @multi

        data.merge(
          "org--impound-update-multi-target": "kindSelect",
          action: "#{data[:action]} change->org--impound-update-multi#refreshChecks"
        )
      end

      # The correct kinds for the current impound_record - e.g. no
      # retrieved_by_owner for an unregistered_parking_notification.
      # Never include claim_approved or claim_denied (those go through
      # impound_claims), and never "current" because it can't be set that way.
      def kinds_for_select
        kinds = if @multi
          ImpoundRecordUpdate.kinds_humanized.except(:expired)
        else
          ImpoundRecordUpdate.kinds_humanized.slice(*@impound_record.update_kinds.map(&:to_sym))
        end
        kinds.except(:claim_approved, :claim_denied, :current)
          .map { |kind, text| [text.titleize, kind] }
      end

      def selected_kind
        return @impound_record_update.kind if @impound_record_update.kind.present?

        "retrieved_by_owner" if @multi || @approved_impound_claim.present?
      end

      def locations_enabled?
        @current_organization.enabled?("impound_bikes_locations")
      end

      def location_options
        locations = @current_organization.locations.impound_locations.map { |l| [l.name, l.id] }
        selected = @impound_record_update.location_id || @current_organization.default_impound_location&.id
        options_for_select(locations, selected)
      end

      def unregistered_bike?
        @parking_notification&.unregistered_bike?
      end
    end
  end
end
