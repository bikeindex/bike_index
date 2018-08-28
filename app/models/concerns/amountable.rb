module Amountable
  extend ActiveSupport::Concern

  def amount
    amnt = (amount_cents.to_i / 100.00)
    amnt % 1 != 0 ? amnt : amnt.round
  end

  def amount=(val)
    self.amount_cents = val.to_f * 100
  end
end
