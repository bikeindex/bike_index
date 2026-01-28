# frozen_string_literal: true

# NOTE: this component is here for testing. It uses the same time_localizer.js setup as everything else

module UI::TimeLocalizer
  class ComponentPreview < ApplicationComponentPreview
    def default(time_zone: nil)
      {template: "ui/time_localizer/component_preview/default", locals: {time_zone:}}
    end
  end
end
