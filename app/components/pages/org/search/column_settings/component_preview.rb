# frozen_string_literal: true

module Pages
  module Org
    module Search
      module ColumnSettings
        # The panel renders collapsed, so this opens it from a ColumnSettingsToggle. Its column
        # toggle is the org search's own — checking a box here changes what the real search
        # page shows.
        class ComponentPreview < ApplicationComponentPreview
          # @!group Variants
          # An organization without features — only the columns every organization gets
          def default
            render_panel(enabled_feature_slugs: [])
          end

          # Every feature enabled, so every column shows
          def all_settings
            render_panel(enabled_feature_slugs: OrganizationFeature::EXPECTED_SLUGS)
          end
          # @!endgroup

          private

          def render_panel(enabled_feature_slugs:)
            organization = ::Organization.new(short_name: "Preview", enabled_feature_slugs:)
            settings = ComponentStructs::OrgSearchSettings.new(organization:)

            {template: "pages/org/search/column_settings/component_preview/default",
             locals: {settings:, data: Component.column_settings_data_attributes(settings, collapse: true)}}
          end
        end
      end
    end
  end
end
