# frozen_string_literal: true

module Amountable
  extend ActiveSupport::Concern
  include MoneyFormattable

  def amount
    amnt = (amount_cents.to_i / 100.00)
    amnt % 1 != 0 ? amnt : amnt.round
  end

  def amount=(val)
    self.amount_cents = self.class.convert_to_cents(val)
  end

  def amount_formatted
    self.class.money_formatted(amount_cents, currency)
  end
end
