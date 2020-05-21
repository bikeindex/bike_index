# frozen_string_literal: true

class ExchangeRate < ApplicationRecord
  validates :from, :to, :rate, presence: true
  validates :from, :to, format: { with: /\A[A-Z]{3}\z/, message: "must be a valid ISO currency code" }
  validates :rate, numericality: { greater_than_or_equal_to: 0 }
  validates :to, uniqueness: { scope: :from }

  before_validation :normalize_currency_codes
  before_destroy :forbid_destroying_required_exchange_rate

  def self.add_rate(from_iso_code, to_iso_code, rate)
    exrate = find_or_initialize_by(from: from_iso_code, to: to_iso_code)
    exrate.rate = rate
    exrate if exrate.save
  end

  def self.get_rate(from_iso_code, to_iso_code)
    exrate = find_by(from: from_iso_code, to: to_iso_code)
    exrate&.rate
  end

  def self.required_targets
    I18n.available_locales.map { |locale| I18n.t(locale, scope: [:money, :currencies]) }
  end

  private

  def normalize_currency_codes
    self.from = from&.upcase
    self.to = to&.upcase
  end

  def forbid_destroying_required_exchange_rate
    if from == "USD" && to.in?(self.class.required_targets)
      errors.add :base, "Cannot delete a required exchange rate"
      throw(:abort)
    end
  end
end
