require "active_support/testing/time_helpers"

# Shared helpers for the seed scripts
module SeedHelpers
  extend Functionable
  extend ActiveSupport::Testing::TimeHelpers

  # Seeded records are timestamped across the last hour, rather than all at once:
  # the clock starts an hour ago and each tick moves it forward, stopping at now.
  # Later seeds and jobs touch earlier records, so updated_at is reset to match
  def with_clock
    @clock_end = Time.current
    travel_to(@clock_end - 1.hour)
    yield
    sync_updated_at
  ensure
    travel_back
  end

  def tick
    travel_to([Time.current + rand(20..45).seconds, @clock_end].min)
  end

  def sync_updated_at
    connection = ActiveRecord::Base.connection
    connection.tables.each do |table|
      next unless (%w[created_at updated_at] - connection.columns(table).map(&:name)).empty?

      connection.execute("UPDATE #{connection.quote_table_name(table)} SET updated_at = created_at WHERE updated_at IS DISTINCT FROM created_at")
    end
  end

  # Pick a frame maker weighted by priority (popular manufacturers chosen most
  # often), with the long tail of unprioritized makers appearing ~8% of the
  # time. Falls back to uniform when no priorities are set (e.g. fresh import).
  def weighted_frame_maker_id
    makers = Manufacturer.frame_makers.pluck(:id, :priority)
    prioritized = makers.select { |_id, priority| priority.to_i.positive? }
    return makers.sample.first if prioritized.empty?

    tail = makers - prioritized
    return tail.sample.first if tail.any? && rand < 0.08

    total = prioritized.sum { |_id, priority| priority }
    target = rand(total)
    prioritized.find { |_id, priority| (target -= priority) < 0 }.first
  end
end
