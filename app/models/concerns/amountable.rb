module Amountable
  extend ActiveSupport::Concern

  module ClassMethods
    def default_currency; "USD" end

    def money_formatted(amnt, currency: nil)
      Money.new(amnt || 0, currency || default_currency).format
    end
  end

  def amount
    amnt = (amount_cents.to_i / 100.00)
    amnt % 1 != 0 ? amnt : amnt.round
  end

  def amount=(val)
    self.amount_cents = val.to_f * 100
  end

  def amount_formatted
    money_formatted(amount_cents)
  end
end
