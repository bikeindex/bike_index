# frozen_string_literal: true

module Atoms
  module Org
    module OriginDisplay
      class ComponentPreview < ApplicationComponentPreview
        # Every creation_kind an Ownership produces - POS kinds, bulk imports and origins
        def every_kind
          {template: "atoms/org/origin_display/component_preview/every_kind",
           locals: {ownerships:}}
        end

        private

        def ownerships
          Ownership.creation_kinds.map { ownership_for(it) }
        end

        # The inverse of creation_kind - whichever of the three attributes it would read
        def ownership_for(creation_kind)
          return Ownership.new(bulk_import_id: 1) if creation_kind == :bulk_import
          return Ownership.new(pos_kind: creation_kind) if Organization.pos_kinds.include?(creation_kind.to_s)

          Ownership.new(origin: creation_kind)
        end
      end
    end
  end
end
