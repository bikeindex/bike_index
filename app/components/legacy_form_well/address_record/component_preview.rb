# frozen_string_literal: true

module LegacyFormWell::AddressRecord
  class ComponentPreview < ApplicationComponentPreview
    layout "component_preview_form_wrap"

    # @param organization_id text "Organization ID to render the fields for"
    def default(organization_id: nil)
      {template: "legacy_form_well/address_record/component_preview/default",
        locals: {organization: Organization.friendly_find(organization_id)} }
    end

    # TODO: Figure out how to use slots to actually pass user to these different options
    # def with_organization
    # end

    # def with_organization_with_all_helpers
    # end
  end
end
