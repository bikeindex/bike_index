# frozen_string_literal: true

module Form::LegacyFormWell::AddressRecordWithDefault
  class ComponentPreview < ApplicationComponentPreview
    layout "component_preview_form_wrap"

    def default
      {template: "form/legacy_form_well/address_record_with_default/component_preview/default"}
    end
  end
end
