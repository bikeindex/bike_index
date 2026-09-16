# frozen_string_literal: true

module SharedBlocks
  module Turnstile
    class ComponentPreview < ApplicationComponentPreview
      # The form a rider sees: hidden until the address typed in is one Turnstile asks
      def in_a_form
        {template: "shared_blocks/turnstile/component_preview/in_a_form"}
      end

      # Re-rendered after a submission that already named a risky address
      def already_risky
        render(SharedBlocks::Turnstile::Component.new(email: "rider@yahoo.com"))
      end
    end
  end
end
