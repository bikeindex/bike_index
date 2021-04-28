# frozen_string_literal: true

class UpdateExchangeRatesWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder
  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    24.1.hours
  end

  def perform
    ExchangeRateUpdator.update
  end
end
