# This worker runs all the scheduled workers
# It needs to have a frequency <= the most frequent scheduled worker interval
# It's enqueued by a rake task that runs every minute, and enqueues this job if it .should_enqueue?
# This worker, in turn, runs every scheduled worker that hasn't run for at least as long as its frequency, unless the queue is backed up

class ScheduledWorkerRunner < ScheduledWorker
  sidekiq_options queue: "high_priority"
  HISTORY_KEY = "scheduler_history_#{Rails.env}".freeze

  def self.frequency
    5.minutes
  end

  def self.worker_from_string(worker_string)
    scheduled_workers.detect { |j| j.to_s == worker_string.to_s }
  end

  def self.valid_history_records
    { "last_started" => "s", "last_finished" => "f" }.freeze
  end

  def self.record_key(worker_string, record)
    raise ArgumentError, "Unknown history record type: #{record}" unless valid_history_records[record]
    "#{worker_string}-#{valid_history_records[record]}"
  end

  def self.worker_history(worker_string, record)
    redis { |r| r.hget HISTORY_KEY, record_key(worker_string, record) }
  end

  def self.write_worker_history(worker_string, record, value = Time.now)
    redis { |r| r.hset HISTORY_KEY, record_key(worker_string, record), value }
  end

  def self.scheduled_workers
    [UpdateExpiredInvoiceWorker, UpdateCountsWorker, UpdateOrganizationPosKindWorker] + [self]
  end

  def self.scheduled_non_scheduler_workers
    scheduled_workers.reject { |j| j == ScheduledWorkerRunner }
  end

  def perform
    record_scheduler_started
    self.class.scheduled_non_scheduler_workers.each do |worker|
      worker.perform_async if worker.should_enqueue?
    end
    record_scheduler_finished
  end
end
