# frozen_string_literal: true

class UpdateExchangeRatesWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder
  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    1.day
  end

  def perform
    ExchangeRateUpdator.update
  end
end
