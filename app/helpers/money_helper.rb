module MoneyHelper
  include MoneyRails::ActionViewExtension

  PERMITTED_CURRENCIES = %w[USD EUR CAD].freeze

  # TODO: Add a bank implementation that fetches conversion rate values
  Money.default_bank.add_rate(:USD, :EUR, 0.89)
  Money.default_bank.add_rate(:USD, :CAD, 1.32)

  def default_currency
    currency = t(I18n.locale, scope: [:money, :currencies])
    PERMITTED_CURRENCIES.include?(currency) ? currency : PERMITTED_CURRENCIES.first
  rescue I18n::MissingTranslationData
    return PERMITTED_CURRENCIES.first
  end

  def money_usd(dollars, exchange_to: default_currency)
    Money.new(dollars * 100, :USD).exchange_to(exchange_to)
  end

  def as_currency(dollars_usd, exchange_to: default_currency)
    money_without_cents_and_with_symbol(money_usd(dollars_usd, exchange_to: exchange_to))
  end
end
