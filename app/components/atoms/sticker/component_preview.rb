# frozen_string_literal: true

module Atoms
  module Sticker
    # @label Sticker
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants
      # @param code text "Sticker code to render"
      def default(code: "BR 000 1")
        render(Atoms::Sticker::Component.new(pretty_code: code))
      end

      # @label linked to the sticker's edit page
      def with_url
        render(Atoms::Sticker::Component.new(pretty_code: "BR 000 1", url: "#"))
      end
      # @!endgroup
    end
  end
end
