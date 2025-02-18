# frozen_string_literal: true

class MoneyFormatter
  class << self
    include MoneyRails::ActionViewExtension

    def money_format(amnt, currency = nil)

      Money.new(amnt || 0, currency_name_for(currency)).format
    end

    def money_format_without_cents(amnt, currency = nil)
      money_without_cents_and_with_symbol Money.new(amnt || 0, currency_name_for(currency))
    end

    def convert_to_cents(amnt)
      amnt.to_f * 100
    end

    private

    def currency_name_for(currency = nil)
      currency.present? ? Currency.new(currency).name : Currency.default.name
    end
  end
end
