# frozen_string_literal: true

module UI
  module Forms
    module Email
      class ComponentPreview < ApplicationComponentPreview
        # @!group Variants
        # The suggestion appears on leaving the field -- try "you@gmial.con"
        def default
          {template: "ui/forms/email/component_preview/default"}
        end

        def mistyped
          {template: "ui/forms/email/component_preview/mistyped"}
        end
        # @!endgroup
      end
    end
  end
end
