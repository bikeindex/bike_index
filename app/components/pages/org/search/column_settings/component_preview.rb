# frozen_string_literal: true

module Pages
  module Org
    module Search
      module ColumnSettings
        # The panel renders collapsed, so this opens it from a ColumnSettingsToggle. Its column
        # toggle is the org search's own — checking a box here changes what the real search
        # page shows.
        class ComponentPreview < ApplicationComponentPreview
          def default
            return missing_notice("an organization") if lookbook_organization.blank?

            {template: "pages/org/search/column_settings/component_preview/default",
             locals: {settings:, data: Component.column_toggle_data_attributes(settings, collapse: true)}}
          end

          private

          def settings
            @settings ||= ComponentStructs::OrgSearchSettings.new(organization: lookbook_organization)
          end
        end
      end
    end
  end
end
