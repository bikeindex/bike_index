# frozen_string_literal: true

module Pages
  module Admin
    module Bikes
      module Table
        # The admin bikes index table, also rendered wherever admin lists bikes (the
        # dashboard, an organization, a bulk import, duplicate groups). Pass
        # render_sortable to enable sort links, render_multi_check for the delete
        # checkboxes, and skip_user to drop the owner column.
        class Component < ApplicationComponent
          # The panel groups the time columns under "Time - "; the table headers keep the short names
          COLUMNS = {
            created_at_cell: "Time - Registered",
            updated_cell: "Time - Registration Updated",
            occurred_at_cell: "Time - Status",
            photo_cell: "Photo",
            user_cell: "Sent to",
            claimed_cell: "Claimed",
            manufacturer_cell: "Manufacturer",
            info_cell: "Info",
            propulsion_type_cell: "E-vehicle (propulsion)",
            serial_cell: "Serial",
            created_by_cell: "Created by",
            source_cell: "Source",
            cred_cell: "Cred"
          }.freeze

          DEFAULT_COLUMNS = %i[created_at_cell user_cell manufacturer_cell info_cell created_by_cell].freeze

          HINTS = {occurred_at_cell: "when stolen, impounded, etc", cred_cell: "(credibility score)"}.freeze

          def initialize(bikes:, sort_state: ComponentStructs::SortState.new, no_show_header: false,
            show_serial: false, skip_manufacturer_link: false, render_sortable: false,
            skip_user: false, render_multi_check: false)
            @bikes = bikes
            @sort_state = sort_state
            @no_show_header = no_show_header
            @show_serial = show_serial
            @skip_manufacturer_link = skip_manufacturer_link
            @render_sortable = render_sortable
            @skip_user = skip_user
            @render_multi_check = render_multi_check
          end

          private

          # A duplicate group's table has no header to hang the settings under
          def card_options
            return {} if @no_show_header

            columns = @skip_user ? COLUMNS.except(:user_cell) : COLUMNS
            defaults = [*DEFAULT_COLUMNS, (:serial_cell if @show_serial)].compact
            column_settings = {storage_key: "adminBikesColumns", columns:, defaults:, always_visible: %i[created_at_cell], hints: HINTS,
                               narrow_hidden: %i[user_cell info_cell]}
            form = {url: get_destroy_admin_bike_path(id: "multi_delete"), method: :get} if @render_multi_check
            {column_settings:, form:}
          end
        end
      end
    end
  end
end
