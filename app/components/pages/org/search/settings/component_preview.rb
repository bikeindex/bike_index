# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Settings
        # The panel renders collapsed, so this opens it from the settings button it renders
        # itself; Wrapper's search_page scenario is the band the results card opens instead.
        # Its column toggle is the org search's own — checking a box here changes what the
        # real search page shows.
        class ComponentPreview < ApplicationComponentPreview
          # A box in the page flow, as a registration's other-registrations table opens it
          def default
            return missing_notice("an organization") if lookbook_organization.blank?

            {template: "pages/org/search/settings/component_preview/default",
             locals: {settings:, data: Component.column_toggle_data_attributes(settings)}}
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
