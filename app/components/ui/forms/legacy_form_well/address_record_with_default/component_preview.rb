# frozen_string_literal: true

module UI
  module Forms
    module LegacyFormWell
      module AddressRecordWithDefault
        class ComponentPreview < ApplicationComponentPreview
          layout "component_preview_form_wrap"

          def default
            {template: "ui/forms/legacy_form_well/address_record_with_default/component_preview/default"}
          end
        end
      end
    end
  end
end
