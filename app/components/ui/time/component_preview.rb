# frozen_string_literal: true

module UI
  module Time
    class ComponentPreview < ApplicationComponentPreview
      def default(time_zone: nil)
        {template: "ui/time/component_preview/default", locals: {time_zone:}}
      end
    end
  end
end
