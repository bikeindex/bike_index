# frozen_string_literal: true

module LegacyFormWell::AddressRecord
  class ComponentPreview < ApplicationComponentPreview
    layout "component_preview_form_wrap"

    def default
      {template: "legacy_form_well/address_record/component_preview/default"}
    end

    # TODO: Figure out how to use slots to actually pass user to these different options
    # def with_organization
    # end

    # def with_organization_with_all_helpers
    # end
  end
end
