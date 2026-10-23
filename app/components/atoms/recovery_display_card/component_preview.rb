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
      # @!endgroup
    end
  end
end
