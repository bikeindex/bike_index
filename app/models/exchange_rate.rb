# frozen_string_literal: true

class ExchangeRate < ApplicationRecord
  validates :from, :to, :rate, presence: true
  validates :rate, numericality: { greater_than_or_equal_to: 0 }
  validates :to, uniqueness: { scope: :from }

  def self.get_rate(from_iso_code, to_iso_code)
    exrate = find_by(from: from_iso_code, to: to_iso_code)
    exrate&.rate
  end

  def self.add_rate(from_iso_code, to_iso_code, rate)
    exrate = find_or_initialize_by(from: from_iso_code, to: to_iso_code)
    exrate.rate = rate
    exrate if exrate.save
  end
end
