# frozen_string_literal: true

module UI
  module Forms
    module Turnstile
      class ComponentPreview < ApplicationComponentPreview
        # The form a rider sees: hidden until the address typed in is one Turnstile asks
        def in_a_form
          {template: "ui/forms/turnstile/component_preview/in_a_form", locals: {email: nil}}
        end

        # Re-rendered after a submission that already named a risky address
        def already_risky
          {template: "ui/forms/turnstile/component_preview/in_a_form", locals: {email: "rider@yahoo.com"}}
        end
      end
    end
  end
end
