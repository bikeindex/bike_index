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
          COLUMNS = {
            updated_cell: "Updated",
            user_cell: "Sent to",
            manufacturer_cell: "Manufacturer",
            info_cell: "Info",
            serial_cell: "Serial",
            created_by_cell: "Created by",
            cred_cell: "Cred"
          }.freeze

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

            defaults = @show_serial ? COLUMNS.keys : COLUMNS.keys - [:serial_cell]
            column_settings = {storage_key: "adminBikesColumns", columns: @skip_user ? COLUMNS.except(:user_cell) : COLUMNS,
                               defaults:, narrow_hidden: %i[updated_cell user_cell info_cell cred_cell]}
            form = {url: get_destroy_admin_bike_path(id: "multi_delete"), method: :get} if @render_multi_check
            {column_settings:, form:}
          end
        end
      end
    end
  end
end
