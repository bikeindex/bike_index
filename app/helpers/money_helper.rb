# coding: utf-8
module MoneyHelper
  include MoneyRails::ActionViewExtension

  Money.default_bank = EuCentralBank.new.tap do |bank|
    if !bank.rates_updated_at || bank.rates_updated_at < Time.current - 1.day
      data_dir = Rails.root.join("data/")
      Dir.mkdir(data_dir) unless Dir.exist?(data_dir)
      cache = Rails.root.join("data/exchange_rates.xml")
      bank.save_rates(cache)
      bank.update_rates(cache)
    end
  end

  Money.rounding_mode = BigDecimal::ROUND_HALF_UP
  Money.locale_backend = :i18n

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
