# frozen_string_literal: true

# This is a stand-in until the actual columns are added to the models
module DefaultCurrencyable
  extend ActiveSupport::Concern

  def currency_obj
    Currency.new(Currency.default.slug)
  end

  def currency_symbol
    currency_obj&.symbol
  end

  def currency_name
    currency_obj&.name
  end
end
