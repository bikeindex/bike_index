# frozen_string_literal: true

module ExchangeRateUpdator
  extend self

  def update
    payload = Integrations::ExchangeRateAPIClient.new.latest
    rates = payload.fetch(:rates)
    base_iso = payload.fetch(:base)

    results = rates.map { |target_iso, multiplier|
      ExchangeRate.add_rate(base_iso, target_iso, multiplier)
    }

    results.none?(&:nil?)
  end
end
