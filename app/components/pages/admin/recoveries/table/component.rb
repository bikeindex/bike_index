# frozen_string_literal: true

module Pages
  module Admin
    module Recoveries
      module Table
        class Component < ApplicationComponent
          COLUMNS = {
            photo_cell: "Photo",
            recovered_at_cell: "Recovered",
            date_stolen_cell: "Stolen at",
            status_cell: "Status",
            bike_cell: "Bike",
            owner_cell: "Owner",
            theft_description_cell: "Theft info",
            story_cell: "Recovery story",
            quote_by_cell: "Display name",
            location_string_cell: "Display location",
            location_cell: "Location",
            helped_cell: "Helped",
            shareable_cell: "Shareable"
          }.freeze

          # JS compiles these too, case-insensitively: no lookbehind or \A. Over-matching is fine,
          # a flagged story only asks to be read
          PERSONAL_INFO = {
            phone: {label: "phone number", pattern: /(\+?\d{1,2}[\s.-]?)?(\(\d{3}\)|\d{3})[\s.-]?\d{3}[\s.-]?\d{4}\b/i},
            email: {label: "email address", pattern: /[\w.+-]+@[\w-]+(\.[\w-]+)+/i},
            address: {label: "street address", pattern: /\b\d{1,6}\s+([\w.'-]+\s+){0,3}(street|st|avenue|ave|road|rd|boulevard|blvd|drive|dr|lane|ln|court|ct|highway|hwy)\b|\b[a-z]\d[a-z] ?\d[a-z]\d\b/i}
          }.freeze

          DEFAULT_COLUMNS = (COLUMNS.keys - %i[date_stolen_cell shareable_cell]).freeze

          # edits: {recovery_id => {quote:, quote_by:, location_string:}}, the rows a display failed
          # on, which stay checked. editable: false leaves out the form, for a bike's own recoveries
          def initialize(recoveries:, sort_state:, edits: {}, editable: true)
            @recoveries = recoveries
            @sort_state = sort_state
            @edits = edits
            @editable = editable
          end

          private

          # A bike can be user hidden or deleted
          def rows
            ActiveRecord::Associations::Preloader.new(records: @recoveries.to_a,
              associations: %i[country region_record recovery_display recovering_user]).call
            bikes = Bike.unscoped.where(id: @recoveries.map(&:bike_id))
              .includes(current_ownership: {user: %i[membership_active email_bans_active]}).index_by(&:id)
            @recoveries.map do |recovery|
              bike = bikes[recovery.bike_id]
              defaults = RecoveryDisplay.attributes_from_stolen_record(recovery, bike:).merge(@edits[recovery.id].to_h) if @editable && recovery.waiting_on_decision?
              [recovery, bike, defaults, @edits.key?(recovery.id)]
            end
          end

          # A bike's page has the bike already
          def card_options
            options = {columns: COLUMNS, defaults: DEFAULT_COLUMNS, narrow_hidden: %i[photo_cell recovered_at_cell]}
            return options.merge(storage_key: "adminBikeRecoveriesColumns", defaults: DEFAULT_COLUMNS - %i[photo_cell bike_cell]) unless @editable

            # The filters ride along, so a failed display renders the same page
            options.merge(storage_key: "adminRecoveriesColumns", form: {url: bulk_update_admin_recoveries_path(request.query_parameters), method: :post},
              data: {controller: "admin--personal-info", action: "submit->admin--personal-info#confirmDisplay",
                     "admin--personal-info-patterns-value": PERSONAL_INFO.transform_values { {label: it[:label], source: it[:pattern].source} }.to_json})
          end
        end
      end
    end
  end
end
