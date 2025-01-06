class ScheduledStoreLogSearchesWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder
  MAX_W = 2_000

  def self.frequency
    3.minutes
  end

  def perform(read_log_line = false)
    return enqueue_workers unless read_log_line

    log_line = get_log_line
    return if log_line.blank?
    log_line_attrs = LogSearcher::Parser.parse_log_line(log_line)
    return if log_line_attrs.blank?
    logged_search = LoggedSearch.create(log_line_attrs.merge(log_line: log_line))
    ProcessLoggedSearchWorker.perform_async(logged_search.id) if logged_search.id.present?
    logged_search
  rescue => e
    raise "Error: #{e}, log_line: #{log_line}"
  end

  def get_log_line
    LogSearcher::Reader.get_log_line
  end

  def enqueue_workers
    # If there are too many workers enqueued, don't enqueue more
    if Sidekiq::Queue.new(ProcessLoggedSearchWorker.sidekiq_options["queue"]).count > (MAX_W * 3)
      return
    end

    workers_to_enqueue = LogSearcher::Reader.log_lines_in_redis
    if workers_to_enqueue > MAX_W
      workers_to_enqueue = MAX_W
      # Reschedule enqueuing workers
      ScheduledStoreLogSearchesWorker.perform_in(15.seconds)
    end
    workers_to_enqueue.times do
      ScheduledStoreLogSearchesWorker.perform_async(true)
    end
  end
end
