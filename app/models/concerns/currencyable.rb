# frozen_string_literal: true

module Currencyable
  extend ActiveSupport::Concern

  included do
    enum :currency_enum, Currency::SLUGS
  end

  def currency=(val)
    self.currency_enum = Currency.new(val)&.slug
  end

  def currency_obj
    Currency.new(currency_enum)
  end

  def currency_symbol
    currency_obj&.symbol
  end

  def currency_name
    currency_obj&.name
  end
end
