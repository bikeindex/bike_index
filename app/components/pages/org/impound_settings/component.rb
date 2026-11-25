# frozen_string_literal: true

module Pages
  module Org
    module ImpoundSettings
      # The organization's impound configuration form. The ID prefix field previews the next
      # record's ID as it's edited, and the previous prefixes fill it in (org--impound-settings).
      class Component < ApplicationComponent
        def initialize(organization:, impound_configuration:)
          @organization = organization
          @impound_configuration = impound_configuration
        end

        private

        def form_url
          organization_manage_impounding_path(organization_id: @organization.to_param)
        end

        def public_page_path = organization_impounded_bikes_path(organization_id: @organization.to_param)

        def locations_path = locations_organization_manage_path(organization_id: @organization.to_param)

        def bulk_import_path = new_organization_bulk_import_path(organization_id: @organization.to_param, kind: "impounded")

        def default_location = @organization.default_impound_location
      end
    end
  end
end
