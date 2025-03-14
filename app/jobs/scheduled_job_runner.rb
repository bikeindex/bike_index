# This worker runs all the scheduled workers
# It needs to have a frequency <= the most frequent scheduled worker interval
# It's enqueued by a rake task that runs every minute, and enqueues this job if it .should_enqueue?
# This worker, in turn, runs every scheduled worker that hasn't run for at least as long as its frequency, unless the queue is backed up

class ScheduledJobRunner < ScheduledJob
  sidekiq_options queue: "high_priority"
  HISTORY_KEY = "scheduler_history_#{Rails.env}".freeze

  def self.frequency
    5.minutes
  end

  def self.worker_from_string(worker_string)
    scheduled_jobs.detect { |j| j.to_s == worker_string.to_s }
  end

  def self.valid_history_records
    {"last_started" => "s", "last_finished" => "f"}.freeze
  end

  def self.record_key(worker_string, record)
    raise ArgumentError, "Unknown history record type: #{record}" unless valid_history_records[record]
    "#{worker_string}-#{valid_history_records[record]}"
  end

  def self.worker_history(worker_string, record)
    RedisPool.conn { |r| r.hget(HISTORY_KEY, record_key(worker_string, record)) }
  end

  def self.write_worker_history(worker_string, record, value = Time.current)
    RedisPool.conn { |r| r.hset(HISTORY_KEY, record_key(worker_string, record), value.to_s) }
  end

  def self.scheduled_jobs
    [
      CleanBParamsJob,
      CleanBulkImportJob,
      CreateGraduatedNotificationJob,
      CreateStolenGeojsonJob,
      CreateUserAlertNotificationJob,
      FetchProject529BikesJob,
      FileCacheMaintenanceJob,
      ImpoundExpirationJob,
      ProcessGraduatedNotificationJob,
      ProcessHotSheetJob,
      RemoveUnconfirmedUsersJob,
      ScheduledAutocompleteCheckJob,
      ScheduledBikePossiblyFoundNotificationJob,
      ScheduledEmailSurveyJob,
      ScheduledSearchForExternalRegistryBikesJob,
      ScheduledStoreLogSearchesJob,
      StolenBike::DeactivateExpiredTheftAlertJob,
      StolenBike::UpdateTheftAlertFacebookJob,
      TsvCreatorJob,
      # UnusedOwnershipRemovalJob,
      UpdateCountsJob,
      UpdateEmailDomainJob,
      UpdateExchangeRatesJob,
      UpdateInvoiceJob,
      UpdateManufacturerLogoAndPriorityJob,
      UpdateOrganizationPosKindJob,
      self
    ].freeze
  end

  def self.scheduled_non_scheduler_workers
    scheduled_jobs.reject { |j| j == ScheduledJobRunner }
  end

  def perform
    record_scheduler_started
    self.class.scheduled_non_scheduler_workers.each do |worker|
      worker.perform_async if worker.should_enqueue?
    end
    record_scheduler_finished
  end
end
