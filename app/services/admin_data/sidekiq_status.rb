# frozen_string_literal: true

require "sidekiq/api"

module AdminData
  # Single-payload snapshot of Sidekiq: aggregate stats, per-queue depth/latency,
  # running processes, and a class breakdown of the retry/dead sets.
  module SidekiqStatus
    extend Functionable

    # Guard against scanning a pathologically large retry/dead set on production.
    MAX_SET_SCAN = 5_000

    def call
      stats = ::Sidekiq::Stats.new
      {
        stats: stats_data(stats),
        queues: queues_data(stats),
        processes: processes_data,
        retries_by_class: set_by_class(::Sidekiq::RetrySet.new),
        dead_by_class: set_by_class(::Sidekiq::DeadSet.new)
      }
    end

    #
    # private below here
    #

    def stats_data(stats)
      {
        enqueued: stats.enqueued,
        processed: stats.processed,
        failed: stats.failed,
        scheduled_size: stats.scheduled_size,
        retry_size: stats.retry_size,
        dead_size: stats.dead_size,
        processes_size: stats.processes_size,
        workers_size: stats.workers_size,
        default_queue_latency: stats.default_queue_latency
      }
    end

    def queues_data(stats)
      stats.queue_summaries.map do |queue|
        {name: queue.name, size: queue.size, latency: queue.latency, paused: queue.paused}
      end
    end

    def processes_data
      ::Sidekiq::ProcessSet.new.map do |process|
        {
          identity: process["identity"],
          hostname: process["hostname"],
          pid: process["pid"],
          tag: process["tag"],
          queues: process["queues"],
          concurrency: process["concurrency"],
          busy: process["busy"],
          quiet: process["quiet"] == "true",
          started_at: process["started_at"] && Time.zone.at(process["started_at"]),
          rss: process["rss"]
        }
      end
    end

    def set_by_class(job_set)
      return {too_large: job_set.size} if job_set.size > MAX_SET_SCAN

      job_set.map(&:display_class).tally
    end

    conceal :stats_data, :queues_data, :processes_data, :set_by_class
  end
end
