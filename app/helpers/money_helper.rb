# coding: utf-8
module MoneyHelper
  include MoneyRails::ActionViewExtension

  # TODO: Add a bank implementation that fetches conversion rate values
  Money.default_bank.add_rate(:USD, :EUR, 0.88)
  Money.rounding_mode = BigDecimal::ROUND_HALF_UP

  # Return the currency abbreviation (USD, EUR) for the current locale.
  def default_currency
    t(I18n.locale, scope: [:money, :currencies])
  end

  # Return a list of currency abbreviations (USD, EUR) for all available locales.
  def available_currencies
    I18n.available_locales.map { |locale| t(locale, scope: [:money, :currencies]) }
  end

  # Return a list of currency symbols and abbreviations for all available locales:
  # ["$ (USD)", "€ (EUR)"]
  def currency_symbols
    I18n.available_locales.map do |locale|
      [
        I18n.with_locale(locale) { number_to_currency(1, format: "%u") },
        "(#{t(locale, scope: [:money, :currencies])})",
      ].join(" ")
    end
  end

  def money_usd(dollars, exchange_to: default_currency)
    Money.new(dollars * 100, :USD).exchange_to(exchange_to)
  end

  def as_currency(dollars_usd, exchange_to: default_currency)
    money_without_cents_and_with_symbol(money_usd(dollars_usd, exchange_to: exchange_to))
  end
end
