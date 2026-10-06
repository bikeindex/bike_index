# frozen_string_literal: true

module Atoms
  module ShortId
    # @label Short ID
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants
      # @param id text "ID to render"
      def default(id: "r/21J-HW")
        render(Atoms::ShortId::Component.new(short_id: id))
      end

      # @label short (decimal) id
      def decimal
        render(Atoms::ShortId::Component.new(short_id: "r/36"))
      end
      # @!endgroup
    end
  end
end
