module Amountable
  extend ActiveSupport::Concern

  def amount
    amount_cents.to_i / 100.00
  end
end
