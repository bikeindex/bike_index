# frozen_string_literal: true

module Atoms
  module Org
    module OriginDisplay
      class ComponentPreview < ApplicationComponentPreview
        # Every creation_kind an Ownership produces - POS kinds, bulk imports and origins
        def every_kind
          {template: "atoms/org/origin_display/component_preview/every_kind",
           locals: {creation_kinds: Ownership.creation_kinds}}
        end
      end
    end
  end
end
