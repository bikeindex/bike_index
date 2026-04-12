# frozen_string_literal: true

module Form::AddressRecordWithDefault
  class ComponentPreview < ApplicationComponentPreview
    layout "component_preview_form_wrap"

    def default
      {template: "form/address_record_with_default/component_preview/default"}
    end
  end
end
