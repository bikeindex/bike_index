require "active_support/testing/time_helpers"

# Shared helpers for the seed scripts
module SeedHelpers
  extend Functionable
  extend ActiveSupport::Testing::TimeHelpers

  # Published in the README, and .github/workflows/ios-e2e.yml signs in with it
  PASSWORD = "pleaseplease12"

  # Seeded records are timestamped across the last week, rather than all at once:
  # the clock starts a week ago and each tick moves it forward, stopping at now.
  # Later seeds and jobs touch earlier records, so updated_at is reset to match
  def with_clock
    @clock_end = Time.current
    clock_start = (@clock_end - 1.week).change(usec: 0) # travel_to drops usec
    travel_to(clock_start)
    yield
    sync_updated_at(since: clock_start)
  ensure
    @clock_end = nil
    travel_back
  end

  # A no-op outside with_clock, where bin/docker-entrypoint runs a seed on its own
  def tick
    return unless @clock_end

    travel_to([Time.current + rand(60..130).minutes, @clock_end].min)
  end

  # R2 rejects a request signed with a clock more than 15 minutes off (RequestTimeTooSkewed)
  def without_clock
    seeded_time = Time.current
    travel_back
    yield
  ensure
    travel_to(seeded_time)
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

  def bike_params(owner_email:, manufacturer_id: nil)
    {
      cycle_type: "bike",
      propulsion_type: "foot-pedal",
      serial_number: (0...10).map { rand(65..90).chr }.join,
      manufacturer_id: manufacturer_id || weighted_frame_maker_id,
      primary_frame_color_id: Color.pluck(:id).sample,
      rear_tire_narrow: "true",
      handlebar_type: HandlebarType.slugs.first,
      owner_email:
    }
  end

  def seed_bike(creator:, user:, params:, origin: nil, label: "bike")
    tick
    b_param = BParam.create!(creator: user, params:)
    b_param.origin = origin if origin
    bike = creator.create_bike(b_param)
    puts "\n #{label} error \n #{b_param.bike_errors}" if bike.errors.any?
    bike
  end
end
