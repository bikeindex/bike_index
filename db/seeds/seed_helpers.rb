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
    clock_start = (@clock_end - 1.hour).change(usec: 0) # travel_to drops usec
    travel_to(clock_start)
    yield
    sync_updated_at(since: clock_start)
  ensure
    travel_back
  end

  def tick
    travel_to([Time.current + rand(20..45).seconds, @clock_end].min)
  end

  def sync_updated_at(since:)
    connection = ActiveRecord::Base.connection
    tables = connection.select_values(<<~SQL)
      SELECT c.table_name FROM information_schema.columns c
      JOIN information_schema.tables t USING (table_schema, table_name)
      WHERE c.table_schema = current_schema() AND t.table_type = 'BASE TABLE'
        AND c.column_name IN ('created_at', 'updated_at')
      GROUP BY c.table_name HAVING count(*) = 2
    SQL
    connection.execute(tables.map { |table|
      "UPDATE #{connection.quote_table_name(table)} SET updated_at = created_at " \
        "WHERE created_at >= #{connection.quote(since)} AND updated_at IS DISTINCT FROM created_at;"
    }.join("\n"))
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
