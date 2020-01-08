# frozen_string_literal: true

module MoneyFormattable
  extend ActiveSupport::Concern

  module ClassMethods
    def default_currency; "USD" end

    def money_formatted(amnt, currency=nil)
      Money.new(amnt || 0, currency || default_currency).format
    end

    def convert_to_cents(amnt)
      amnt.to_f * 100
    end
  end
end
