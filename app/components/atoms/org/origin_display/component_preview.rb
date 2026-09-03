# frozen_string_literal: true

module Atoms
  module Org
    module OriginDisplay
      class ComponentPreview < ApplicationComponentPreview
        # Every creation_description an Ownership produces - POS kinds, bulk imports and origins
        def every_type
          {template: "atoms/org/origin_display/component_preview/every_type",
           locals: {creation_descriptions:}}
        end

        private

        def creation_descriptions
          pos_ownerships = Organization.pos_kinds.map { |pos_kind| Ownership.new(pos_kind:) }.select(&:pos?)

          (pos_ownerships + [Ownership.new(bulk_import_id: 1)] + Ownership.origins.map { |origin| Ownership.new(origin:) })
            .map(&:creation_description).uniq
        end
      end
    end
  end
end
