# frozen_string_literal: true

module UI
  module Forms
    module AddressGroup
      class ComponentPreview < ApplicationComponentPreview
        def default
          {template: "ui/forms/address_group/component_preview/default",
           locals: {required: false, street_2: false}}
        end

        # Every field but street_2 is required
        def required
          {template: "ui/forms/address_group/component_preview/default",
           locals: {required: true, street_2: true}}
        end
      end
    end
  end
end
