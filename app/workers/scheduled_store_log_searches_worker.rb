class ScheduledStoreLogSearchesWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder
  MAX_W = 1_000

  def self.frequency
    1.minute
  end

  def perform(read_log_line = false)
    return enqueue_workers unless read_log_line

    log_line = get_log_line
    return if log_line.blank?
    log_line_attrs = LogSearcher::Parser.parse_log_line(log_line)
    return if log_line_attrs.blank?
    LoggedSearch.create(log_line_attrs.merge(log_line: log_line))
  rescue => e
    raise "Error: #{e}, log_line: #{log_line}"
  end

  def get_log_line
    LogSearcher::Reader.get_log_line
  end

  def enqueue_workers
    workers_to_enqueue = LogSearcher::Reader.log_lines_in_redis
    workers_to_enqueue = MAX_W if workers_to_enqueue > MAX_W
    workers_to_enqueue.times do
      ScheduledStoreLogSearchesWorker.perform_async(true)
    end
  end
end
