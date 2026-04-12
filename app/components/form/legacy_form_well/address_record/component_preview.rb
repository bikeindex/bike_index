# frozen_string_literal: true

module Form::LegacyFormWell::AddressRecord
  class ComponentPreview < ApplicationComponentPreview
    layout "component_preview_form_wrap"

    # @param organization_id text "Organization ID to render the fields for"
    def default(organization_id: nil)
      organization = Organization.friendly_find(organization_id)

      {template: "form/legacy_form_well/address_record/component_preview/default",
       locals: {organization:}}
    end

    def impounded_bike
      {template: "form/legacy_form_well/address_record/component_preview/default",
       locals: {bike_status: "status_impounded"}}
    end

    # TODO: WTF, why isn't the @param working :/
    # def with_organization
    # end

    # def with_organization_with_all_helpers
    # end
  end
end
