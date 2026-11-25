# frozen_string_literal: true

module Atoms
  module RecoveryDisplayCard
    # Reads the seeded recovery displays, which have photos
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants
      def default
        render(Atoms::RecoveryDisplayCard::Component.new(recovery_display: RecoveryDisplay.with_photo.first,
          html_class: "tw:flex tw:max-w-75"))
      end

      def without_attribution
        render(Atoms::RecoveryDisplayCard::Component.new(html_class: "tw:flex tw:max-w-75",
          recovery_display: RecoveryDisplay.with_photo.first.tap { it.quote_by = nil }))
      end

      def with_link
        render(Atoms::RecoveryDisplayCard::Component.new(html_class: "tw:flex tw:max-w-75",
          recovery_display: RecoveryDisplay.with_photo.first.tap { it.link = "https://twitter.com/stolenbikessfo/status/537025628319805443" }))
      end

      def without_photo
        render(Atoms::RecoveryDisplayCard::Component.new(html_class: "tw:flex tw:max-w-75",
          recovery_display: RecoveryDisplay.new(quote: "Got it back", quote_by: "Sandy", recovered_at: Time.current)))
      end
      # @!endgroup
    end
  end
end
