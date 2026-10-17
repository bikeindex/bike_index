# frozen_string_literal: true

module Atoms
  module CurrencyMillions
    # @label Currency millions
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants
      # @param dollars_usd number "Amount in USD"
      def default(dollars_usd: 38_412_345)
        render(Atoms::CurrencyMillions::Component.new(dollars_usd:))
      end

      # @label under a million
      def under_a_million
        render(Atoms::CurrencyMillions::Component.new(dollars_usd: 450_000))
      end
      # @!endgroup
    end
  end
end
