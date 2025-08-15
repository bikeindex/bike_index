# frozen_string_literal: true

module Amountable
  extend ActiveSupport::Concern

  def self.to_cents(amount_float)
    return nil if amount_float.blank?

    ((amount_float || 0).to_f * 100.00).round
  end

  def amount
    amnt = (amount_cents.to_i / 100.00)
    (amnt % 1 != 0) ? amnt : amnt.round
  end

  def amount=(val)
    self.amount_cents = MoneyFormatter.convert_to_cents(val)
  end

  def amount_with_nil
    return nil if amount_cents.blank?

    amount
  end

  def amount_with_nil=(val)
    self.amount_cents = val.present? ? MoneyFormatter.convert_to_cents(val) : nil
  end

  def amount_formatted
    MoneyFormatter.money_format(amount_cents, currency_name)
  end
end
