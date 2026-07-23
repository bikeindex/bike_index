# frozen_string_literal: true

module UI
  module Details
    # The details controller has no component; this previews its markup contract
    # (a native <details>/<summary> with a content target) and CSS keyed off [open].
    class ComponentPreview < ApplicationComponentPreview
      def with_animation
        {template: "ui/details/component_preview/with_animation"}
      end
    end
  end
end
