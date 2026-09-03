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
          pos_kinds = Organization.pos_kinds.select { Organization.pos?(it) }

          (pos_kinds.map { Ownership.new(pos_kind: it) } + [Ownership.new(bulk_import_id: 1)] +
            Ownership.origins.map { Ownership.new(origin: it) }).uniq(&:creation_kind)
        end
      end
    end
  end
end
