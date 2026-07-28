# frozen_string_literal: true

module Atom
  module ShortId
    # @label Short ID
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants
      # @param id text "ID to render"
      def default(id: "r/21J-HW")
        render(Atom::ShortId::Component.new(short_id: id))
      end

      # @label short (decimal) id
      def decimal
        render(Atom::ShortId::Component.new(short_id: "r/36"))
      end

      # @label with extra classes appended
      def with_html_class
        render(Atom::ShortId::Component.new(short_id: "r/21J-HW", html_class: "tw:text-base"))
      end
      # @!endgroup
    end
  end
end
