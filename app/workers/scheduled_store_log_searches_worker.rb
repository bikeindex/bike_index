class ScheduledStoreLogSearchesWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    1.minute
  end

  def perform(read_log_line = false)
    return enqueue_workers unless read_log_line

    log_line = get_log_line
    log_line_attrs = LogSearcher::Parser.parse_log_line(log_line)
    LoggedSearch.create(log_line_attrs.merge(log_line: log_line))
  end

  def get_log_line
    LogSearcher::Reader.get_log_line
  end

  def enqueue_workers
    LogSearcher::Reader.log_lines_in_redis.times do
      ScheduledStoreLogSearchesWorker.perform_async(true)
    end
  end
end
