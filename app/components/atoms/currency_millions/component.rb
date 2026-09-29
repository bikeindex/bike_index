# frozen_string_literal: true

module Atoms
  module CurrencyMillions
    # A USD amount in the locale's currency, floored to whole millions - "$38M+". Below a
    # million it's the whole amount, "$450,000+"
    class Component < ApplicationComponent
      include MoneyHelper

      def initialize(dollars_usd:, animate: false, currency: default_currency)
        @money = money_usd(dollars_usd, exchange_to: currency)
        @animate = animate
      end

      def call
        tag.span("#{prefix}#{number}#{suffix}", data: @animate ? animate_data : {})
      end

      private

      def millions? = @money.amount >= 1_000_000

      # Split around the digits, since the currency decides which side its symbol goes on
      def currency_parts
        @currency_parts ||= money_without_cents_and_with_symbol(shown_money).match(/\A(\D*)(\d(?:.*\d)?)(\D*)\z/)
      end

      def shown_money = millions? ? Money.from_amount((@money.amount / 1_000_000).floor, @money.currency) : @money

      def prefix = currency_parts[1]

      def number = currency_parts[2]

      def suffix = "#{"M" if millions?}+#{currency_parts[3]}"

      def animate_data
        {controller: "homepage--animate-count", "homepage--animate-count-target-value": number.gsub(/\D/, ""),
         "homepage--animate-count-prefix-value": prefix, "homepage--animate-count-suffix-value": suffix}
      end
    end
  end
end
