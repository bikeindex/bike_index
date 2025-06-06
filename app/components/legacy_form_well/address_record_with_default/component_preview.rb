# frozen_string_literal: true

module LegacyFormWell::AddressRecordWithDefault
  class ComponentPreview < ApplicationComponentPreview
    # TODO: This should be merged into the normal layout, now that the normal layout includes revised styles
    layout "component_preview_form_wrap"

    def default
      {template: "legacy_form_well/address_record_with_default/component_preview/default"}
    end
  end
end
