# frozen_string_literal: true

class UpdateExchangeRatesJob < ScheduledJob
  prepend ScheduledJobRecorder
  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    24.1.hours
  end

  def perform
    ExchangeRateUpdator.update
  end
end
