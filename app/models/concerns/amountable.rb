module Amountable
  extend ActiveSupport::Concern

  def currency
    "USD"
  end

  def amount
    amnt = (amount_cents.to_i / 100.00)
    amnt % 1 != 0 ? amnt : amnt.round
  end

  def amount=(val)
    self.amount_cents = val.to_f * 100
  end

  def money_formatted(amnt)
    Money.new(amnt || 0, currency).format
  end

  def amount_formatted
    money_formatted(amount_cents)
  end
end
