# frozen_string_literal: true

module SharedBlocks
  module Turnstile
    class ComponentPreview < ApplicationComponentPreview
      # Cloudflare's published always-passes key, so the previews render without
      # TURNSTILE_SITE_KEY being set
      SITE_KEY = "1x00000000000000000000AA"
      # The form a rider sees: hidden until the address typed in is one Turnstile asks
      def in_a_form
        {template: "shared_blocks/turnstile/component_preview/in_a_form"}
      end

      # Re-rendered after a submission that already named a risky address
      def already_risky
        render(SharedBlocks::Turnstile::Component.new(email: "rider@yahoo.com",
          site_key: SITE_KEY))
      end

      # Unconfigured - every environment until the keys are set
      def without_keys
        render(SharedBlocks::Turnstile::Component.new)
      end
    end
  end
end
